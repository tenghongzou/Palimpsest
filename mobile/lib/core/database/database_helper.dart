import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const int _currentVersion = 2;
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'palimpsest.db');
    return openDatabase(
      path,
      version: _currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Uses same schema as shared/sqlite-schema/migrations/
    await db.execute('''
      CREATE TABLE local_novels (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author_name TEXT NOT NULL,
        cover_url TEXT,
        cover_local_path TEXT,
        description TEXT,
        status TEXT DEFAULT 'ongoing',
        language TEXT DEFAULT 'zh-TW',
        total_words INTEGER DEFAULT 0,
        total_chapters INTEGER DEFAULT 0,
        avg_rating REAL DEFAULT 0,
        latest_chapter_title TEXT,
        latest_chapter_at TEXT,
        cached_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE local_chapters (
        id TEXT PRIMARY KEY,
        novel_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        chapter_number INTEGER NOT NULL,
        word_count INTEGER DEFAULT 0,
        is_downloaded INTEGER DEFAULT 0,
        cached_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (novel_id) REFERENCES local_novels(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_local_chapters_novel ON local_chapters(novel_id, chapter_number)');

    await db.execute('''
      CREATE TABLE local_reading_progress (
        id TEXT PRIMARY KEY,
        novel_id TEXT NOT NULL UNIQUE,
        chapter_id TEXT NOT NULL,
        paragraph_index INTEGER DEFAULT 0,
        scroll_offset REAL DEFAULT 0,
        read_at TEXT DEFAULT (datetime('now')),
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE local_bookmarks (
        id TEXT PRIMARY KEY,
        novel_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        chapter_title TEXT,
        paragraph_index INTEGER DEFAULT 0,
        note TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE local_bookshelf (
        id TEXT PRIMARY KEY,
        novel_id TEXT NOT NULL UNIQUE,
        group_name TEXT DEFAULT 'default',
        sort_order INTEGER DEFAULT 0,
        added_at TEXT DEFAULT (datetime('now')),
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE local_reading_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        font_size INTEGER DEFAULT 18,
        line_height REAL DEFAULT 1.8,
        letter_spacing REAL DEFAULT 0.0,
        margin INTEGER DEFAULT 16,
        font_family TEXT DEFAULT 'system',
        theme TEXT DEFAULT 'white',
        reading_mode TEXT DEFAULT 'scroll',
        brightness INTEGER DEFAULT 100,
        keep_screen_on INTEGER DEFAULT 1,
        auto_chapter INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE local_sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT,
        retry_count INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE local_meta (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // Insert default meta
    await db.insert('local_meta', {'key': 'db_version', 'value': '$_currentVersion'});
    await db.insert('local_meta', {'key': 'max_cache_size_bytes', 'value': '524288000'});
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Run migrations sequentially from oldVersion to newVersion
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      await _migrate(db, v);
    }
  }

  static Future<void> _migrate(Database db, int version) async {
    switch (version) {
      case 2:
        await _migrateV2(db);
        break;
    }
  }

  // v2: Add translation cache table and full-text search support
  static Future<void> _migrateV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_translation_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_text_hash TEXT NOT NULL,
        source_lang TEXT NOT NULL,
        target_lang TEXT NOT NULL,
        translated_text TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now')),
        UNIQUE(source_text_hash, source_lang, target_lang)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_translation_lookup ON local_translation_cache(source_text_hash, source_lang, target_lang)'
    );

    // Add view_count to local_novels for offline ranking
    await db.execute('ALTER TABLE local_novels ADD COLUMN view_count INTEGER DEFAULT 0');

    // Update meta version
    await db.rawUpdate(
      "UPDATE local_meta SET value = '2', updated_at = datetime('now') WHERE key = 'db_version'"
    );
  }

  // Helper: save reading settings to local DB
  static Future<void> saveReadingSettings({
    required int fontSize,
    required double lineHeight,
    required double letterSpacing,
    required int margin,
    required String fontFamily,
    required String theme,
    required String readingMode,
    required int brightness,
    required bool keepScreenOn,
    required bool autoChapter,
  }) async {
    final db = await database;
    await db.rawInsert('''
      INSERT OR REPLACE INTO local_reading_settings
        (id, font_size, line_height, letter_spacing, margin, font_family, theme, reading_mode, brightness, keep_screen_on, auto_chapter, updated_at)
      VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
    ''', [
      fontSize, lineHeight, letterSpacing, margin, fontFamily,
      theme, readingMode, brightness,
      keepScreenOn ? 1 : 0, autoChapter ? 1 : 0,
    ]);
  }

  // Helper: load reading settings from local DB
  static Future<Map<String, dynamic>?> loadReadingSettings() async {
    final db = await database;
    final results = await db.query('local_reading_settings', where: 'id = 1');
    if (results.isEmpty) return null;
    return results.first;
  }

  // Helper: get total cache size in bytes
  static Future<int> getCacheSize() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(LENGTH(content)) as total_bytes FROM local_chapters WHERE is_downloaded = 1"
    );
    return (result.first['total_bytes'] as int?) ?? 0;
  }

  // Helper: clear all cached chapter content
  static Future<void> clearChapterCache() async {
    final db = await database;
    await db.delete('local_chapters');
    await db.rawUpdate(
      "UPDATE local_meta SET value = '0', updated_at = datetime('now') WHERE key = 'cache_size_bytes'"
    );
  }

  // Helper: close database (for testing or app termination)
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
