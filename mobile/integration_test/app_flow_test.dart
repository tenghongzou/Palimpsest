// Core reading flow on a device or emulator, with the network faked:
//   flutter test integration_test
// The same flow also runs without a device in test/flows/core_flow_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:palimpsest/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/core_flow.dart';
import '../test/support/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('browse, open a novel, read, go to the next chapter and bookmark', (tester) async {
    // The device's own SQLite (sqflite plugin), in memory.
    final env = await TestEnv.create(openDb: () => DatabaseHelper.open(databaseFactory, inMemoryDatabasePath));
    await runCoreReadingFlow(tester, env);
    await env.dispose();
  });
}
