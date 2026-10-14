/// One migration from shared/sqlite-schema/migrations (vNNN_name.sql).
/// The version is stored in SQLite's `PRAGMA user_version`, exactly as the
/// web client (sql.js) does, so both platforms agree on what is applied.
class SqliteMigration {
  final int version;
  final String name;
  final String sql;

  const SqliteMigration({required this.version, required this.name, required this.sql});
}
