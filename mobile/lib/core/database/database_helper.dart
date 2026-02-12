import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
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
      version: 1,
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
    await db.insert('local_meta', {'key': 'db_version', 'value': '1'});
    await db.insert('local_meta', {'key': 'max_cache_size_bytes', 'value': '524288000'});
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // TODO: handle migrations
  }
}
