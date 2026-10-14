import 'package:sqflite/sqflite.dart';

import 'sql_statements.dart';
import 'sqlite_migration.dart';
import 'sqlite_migrations.g.dart';

/// Applies shared/sqlite-schema migrations by `PRAGMA user_version`, the same
/// way web/utils/localDb.ts does, so the shared SQL is the single source of
/// truth for the local schema on both clients.
class SqliteMigrator {
  final List<SqliteMigration> migrations;

  const SqliteMigrator({this.migrations = sqliteMigrations});

  int get latestVersion => migrations.isEmpty ? 0 : migrations.last.version;

  static Future<int> userVersion(DatabaseExecutor db) async {
    final rows = await db.rawQuery('PRAGMA user_version');
    return (rows.first.values.first as int?) ?? 0;
  }

  /// Brings [db] up to the latest migration. Each migration runs in its own
  /// transaction together with the user_version bump.
  Future<void> migrate(Database db) async {
    var version = await userVersion(db);

    if (await isLegacyMobileSchema(db, version)) {
      await db.transaction((txn) async {
        await _repairLegacyMobileSchema(txn);
        await txn.execute('PRAGMA user_version = 1');
      });
      version = 1;
    }

    for (final migration in migrations) {
      if (migration.version <= version) continue;
      await db.transaction((txn) async {
        for (final statement in splitSqlStatements(migration.sql)) {
          await txn.execute(statement);
        }
        await txn.execute('PRAGMA user_version = ${migration.version}');
      });
      version = migration.version;
    }
  }

  /// Databases created by app versions before the shared migrations were
  /// adopted (mobile db versions 1 and 2) never had local_search_history.
  static Future<bool> isLegacyMobileSchema(DatabaseExecutor db, int version) async {
    if (version < 1 || version > 2) return false;
    return !await _exists(db, 'table', 'local_search_history');
  }

  /// Reshapes a legacy mobile database into the shared v001 schema while
  /// keeping user data (bookmarks, progress, settings, cached chapters).
  Future<void> _repairLegacyMobileSchema(Transaction txn) async {
    // The old v2 upgrade path created local_translation_cache with another
    // shape; it only ever held cache data, so it is rebuilt from scratch.
    if (await _hasColumn(txn, 'local_translation_cache', 'source_text_hash')) {
      await txn.execute('DROP INDEX IF EXISTS idx_translation_lookup');
      await txn.execute('DROP TABLE local_translation_cache');
    }

    final initial = migrations.firstWhere((m) => m.version == 1);
    final create = RegExp(r'^CREATE\s+(TABLE|INDEX)\s+(\w+)', caseSensitive: false);
    final insert = RegExp(r'^INSERT\s+INTO\s+', caseSensitive: false);
    for (final statement in splitSqlStatements(initial.sql)) {
      final match = create.firstMatch(statement);
      if (match != null) {
        if (!await _exists(txn, match.group(1)!.toLowerCase(), match.group(2)!)) {
          await txn.execute(statement);
        }
      } else if (insert.hasMatch(statement)) {
        // Seed rows such as local_meta defaults, without touching existing ones.
        await txn.execute(statement.replaceFirst(insert, 'INSERT OR IGNORE INTO '));
      }
    }

    // Mobile used to call the sepia reader theme 'yellow'.
    await txn.execute("UPDATE local_reading_settings SET theme = 'sepia' WHERE theme = 'yellow'");
    await txn.execute(
      "UPDATE local_meta SET value = '1', updated_at = datetime('now') WHERE key = 'db_version'",
    );
  }

  static Future<bool> _exists(DatabaseExecutor db, String type, String name) async {
    final rows = await db.rawQuery(
      'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
      [type, name],
    );
    return rows.isNotEmpty;
  }

  static Future<bool> _hasColumn(DatabaseExecutor db, String table, String column) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((r) => r['name'] == column);
  }
}
