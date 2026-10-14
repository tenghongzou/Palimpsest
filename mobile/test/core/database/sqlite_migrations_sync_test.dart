import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/sync_sqlite_schema.dart' as codegen;

void main() {
  test('sqlite_migrations.g.dart matches shared/sqlite-schema/migrations', () {
    final generated = File(codegen.outputFile).readAsStringSync().replaceAll('\r\n', '\n');
    expect(
      generated,
      codegen.buildMigrationsSource(),
      reason: 'The shared SQL changed: run `dart run tool/sync_sqlite_schema.dart` in mobile/.',
    );
  });
}
