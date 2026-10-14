import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/database/database_helper.dart';
import 'package:palimpsest/core/database/offline_store.dart';
import 'package:palimpsest/core/database/sql_statements.dart';
import 'package:palimpsest/core/database/sqlite_migrations.g.dart';
import 'package:palimpsest/core/database/sqlite_migrator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The schema created by app versions before the shared migrations were
/// adopted (DatabaseHelper.createSchema, mobile db version 1).
const legacyV1Schema = '''
CREATE TABLE local_novels (id TEXT PRIMARY KEY, title TEXT NOT NULL, author_name TEXT NOT NULL, cover_url TEXT,
  cover_local_path TEXT, description TEXT, status TEXT DEFAULT 'ongoing', language TEXT DEFAULT 'zh-TW',
  total_words INTEGER DEFAULT 0, total_chapters INTEGER DEFAULT 0, avg_rating REAL DEFAULT 0,
  latest_chapter_title TEXT, latest_chapter_at TEXT, cached_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')));
CREATE TABLE local_chapters (id TEXT PRIMARY KEY, novel_id TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL,
  chapter_number INTEGER NOT NULL, word_count INTEGER DEFAULT 0, is_downloaded INTEGER DEFAULT 0,
  cached_at TEXT DEFAULT (datetime('now')), FOREIGN KEY (novel_id) REFERENCES local_novels(id) ON DELETE CASCADE);
CREATE INDEX idx_local_chapters_novel ON local_chapters(novel_id, chapter_number);
CREATE TABLE local_reading_progress (id TEXT PRIMARY KEY, novel_id TEXT NOT NULL UNIQUE, chapter_id TEXT NOT NULL,
  paragraph_index INTEGER DEFAULT 0, scroll_offset REAL DEFAULT 0, read_at TEXT DEFAULT (datetime('now')),
  is_synced INTEGER DEFAULT 0);
CREATE TABLE local_bookmarks (id TEXT PRIMARY KEY, novel_id TEXT NOT NULL, chapter_id TEXT NOT NULL, chapter_title TEXT,
  paragraph_index INTEGER DEFAULT 0, note TEXT, created_at TEXT DEFAULT (datetime('now')), is_synced INTEGER DEFAULT 0,
  is_deleted INTEGER DEFAULT 0);
CREATE TABLE local_bookshelf (id TEXT PRIMARY KEY, novel_id TEXT NOT NULL UNIQUE, group_name TEXT DEFAULT 'default',
  sort_order INTEGER DEFAULT 0, added_at TEXT DEFAULT (datetime('now')), is_synced INTEGER DEFAULT 0,
  is_deleted INTEGER DEFAULT 0);
CREATE TABLE local_reading_settings (id INTEGER PRIMARY KEY CHECK (id = 1), font_size INTEGER DEFAULT 18,
  line_height REAL DEFAULT 1.8, letter_spacing REAL DEFAULT 0.0, margin INTEGER DEFAULT 16,
  font_family TEXT DEFAULT 'system', theme TEXT DEFAULT 'white', reading_mode TEXT DEFAULT 'scroll',
  brightness INTEGER DEFAULT 100, keep_screen_on INTEGER DEFAULT 1, auto_chapter INTEGER DEFAULT 1,
  updated_at TEXT DEFAULT (datetime('now')));
CREATE TABLE local_sync_queue (id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT NOT NULL, entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL, payload TEXT, retry_count INTEGER DEFAULT 0, created_at TEXT DEFAULT (datetime('now')));
CREATE TABLE local_meta (key TEXT PRIMARY KEY, value TEXT, updated_at TEXT DEFAULT (datetime('now')));
INSERT INTO local_meta (key, value) VALUES ('db_version', '1');
INSERT INTO local_meta (key, value) VALUES ('max_cache_size_bytes', '524288000');
''';

/// The old mobile v1 -> v2 upgrade (_migrateV2).
const legacyV2Upgrade = '''
CREATE TABLE IF NOT EXISTS local_translation_cache (id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_text_hash TEXT NOT NULL, source_lang TEXT NOT NULL, target_lang TEXT NOT NULL,
  translated_text TEXT NOT NULL, created_at TEXT DEFAULT (datetime('now')),
  UNIQUE(source_text_hash, source_lang, target_lang));
CREATE INDEX IF NOT EXISTS idx_translation_lookup ON local_translation_cache(source_text_hash, source_lang, target_lang);
ALTER TABLE local_novels ADD COLUMN view_count INTEGER DEFAULT 0;
UPDATE local_meta SET value = '2', updated_at = datetime('now') WHERE key = 'db_version';
''';

Future<Database> rawDb() =>
    databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));

Future<void> run(Database db, String sql) async {
  for (final s in splitSqlStatements(sql)) {
    await db.execute(s);
  }
}

/// Tables/indexes with their columns, ignoring [ignoreColumns].
Future<Map<String, List<String>>> schemaOf(Database db, {Set<String> ignoreColumns = const {}}) async {
  final objects = await db.rawQuery(
    "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
  );
  final result = <String, List<String>>{};
  for (final o in objects) {
    final name = o['name'] as String;
    if (o['type'] == 'table') {
      final cols = await db.rawQuery('PRAGMA table_info($name)');
      result['table $name'] = cols
          .map((c) => '${c['name']} ${c['type']} ${c['dflt_value']}')
          .where((c) => !ignoreColumns.contains(c.split(' ').first))
          .toList();
    } else {
      result['${o['type']} $name'] = const [];
    }
  }
  return result;
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('splitSqlStatements', () {
    test('splits on semicolons outside comments and quotes', () {
      final statements = splitSqlStatements('''
-- a comment; with a semicolon
CREATE TABLE t (a TEXT DEFAULT 'x;y', b TEXT DEFAULT "q""uote;");
/* block; comment */ INSERT INTO t (a) VALUES ('it''s; fine');
INSERT INTO t (a) VALUES (NULL)
''');
      expect(statements, hasLength(3));
      expect(statements[0], startsWith('CREATE TABLE t'));
      expect(statements[0], contains("'x;y'"));
      expect(statements[1], contains("'it''s; fine'"));
      expect(statements[2], 'INSERT INTO t (a) VALUES (NULL)');
    });

    test('keeps trigger bodies together', () {
      final statements = splitSqlStatements('''
CREATE TRIGGER tr AFTER INSERT ON t BEGIN
  UPDATE t SET a = 1;
  UPDATE t SET b = 2;
END;
SELECT 1;
''');
      expect(statements, hasLength(2));
      expect(statements.first, endsWith('END'));
    });
  });

  group('SqliteMigrator', () {
    test('a fresh database gets exactly the shared schema and user_version', () async {
      final migrated = await DatabaseHelper.open(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
      final reference = await rawDb();
      for (final m in sqliteMigrations) {
        await run(reference, m.sql);
      }

      expect(await schemaOf(migrated), await schemaOf(reference));
      expect(await SqliteMigrator.userVersion(migrated), sqliteMigrations.last.version);
      final meta = await migrated.query('local_meta', orderBy: 'key');
      expect(meta.map((r) => r['key']), containsAll(['db_version', 'last_sync_at', 'cache_size_bytes', 'max_cache_size_bytes']));

      // Running again changes nothing.
      await const SqliteMigrator().migrate(migrated);
      expect(await schemaOf(migrated), await schemaOf(reference));
      await migrated.close();
      await reference.close();
    });

    for (final legacy in [
      (name: 'mobile v1', sql: legacyV1Schema, version: 1),
      (name: 'mobile v2 (fresh install)', sql: legacyV1Schema, version: 2),
      (name: 'mobile v2 (upgraded from v1)', sql: legacyV1Schema + legacyV2Upgrade, version: 2),
    ]) {
      test('upgrades a ${legacy.name} database in place without losing data', () async {
        final db = await rawDb();
        await run(db, legacy.sql);
        await db.execute('PRAGMA user_version = ${legacy.version}');
        await db.insert('local_bookmarks', {'id': 'b1', 'novel_id': 'n1', 'chapter_id': 'c1', 'paragraph_index': 3});
        await db.insert('local_reading_progress', {'id': 'n1', 'novel_id': 'n1', 'chapter_id': 'c1'});
        await db.insert('local_chapters', {'id': 'c1', 'novel_id': 'n1', 'title': 't', 'content': '內容', 'chapter_number': 1});
        await db.insert('local_reading_settings', {'id': 1, 'font_size': 22, 'theme': 'yellow'});
        if (legacy.sql.contains('source_text_hash')) {
          await db.insert('local_translation_cache',
              {'source_text_hash': 'h', 'source_lang': 'zh-TW', 'target_lang': 'en', 'translated_text': 'x'});
        }

        await const SqliteMigrator().migrate(db);

        final fresh = await DatabaseHelper.open(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
        expect(await schemaOf(db, ignoreColumns: {'view_count'}), await schemaOf(fresh));
        expect(await SqliteMigrator.userVersion(db), sqliteMigrations.last.version);

        final store = OfflineStore(db);
        expect((await store.bookmarks()).single.paragraphIndex, 3);
        expect((await store.getProgress('n1'))?['chapter_id'], 'c1');
        expect((await store.getChapter('c1'))?.content, '內容');
        final settings = (await store.loadReadingSettings())!.$1;
        expect(settings.fontSize, 22);
        expect(settings.theme, 'sepia');
        expect(await store.getMeta('max_cache_size_bytes'), '524288000');
        expect(await store.getMeta('cache_size_bytes'), isNotNull);

        // The shared tables work after the upgrade.
        await store.addSearchKeyword('燈塔');
        expect(await store.recentSearches(), ['燈塔']);
        await store.saveTranslation(chapterId: 'c1', sourceLang: 'zh-TW', targetLang: 'en', title: 'T', content: 'C');
        expect((await store.getTranslation('c1', 'en'))?.content, 'C');
        await db.close();
        await fresh.close();
      });
    }
  });
}
