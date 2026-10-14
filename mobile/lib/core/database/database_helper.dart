import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'offline_store.dart';
import 'sqlite_migrator.dart';

/// Opens the local store. Tests override this with an in-memory database.
final offlineStoreProvider = Provider<Future<OfflineStore> Function()>((ref) {
  return () async => OfflineStore(await DatabaseHelper.database);
});

class DatabaseHelper {
  static Database? _database;
  static Future<Database>? _opening;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _opening ??= _initDatabase().then((db) => _database = db).whenComplete(() => _opening = null);
    return _opening!;
  }

  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'palimpsest.db');
    return open(databaseFactory, path);
  }

  /// Opens [path] and applies the shared SQLite migrations
  /// (shared/sqlite-schema/migrations) by `PRAGMA user_version`. Databases
  /// from older app versions (mobile db versions 1 and 2) are upgraded in place.
  static Future<Database> open(DatabaseFactory factory, String path) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: path != inMemoryDatabasePath),
    );
    await const SqliteMigrator().migrate(db);
    return db;
  }

  /// Total size of stored chapter text in UTF-8 bytes.
  static Future<int> getCacheSize() async => OfflineStore(await database).cacheSizeBytes();

  /// Removes every stored chapter, downloads included.
  static Future<void> clearChapterCache() async {
    final db = await database;
    await db.delete('local_chapters');
    await OfflineStore(db).setMeta('cache_size_bytes', '0');
  }

  /// Closes the database (for tests or app termination).
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
