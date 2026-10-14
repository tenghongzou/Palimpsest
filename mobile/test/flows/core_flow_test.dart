import 'package:flutter_test/flutter_test.dart';

import '../support/core_flow.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('browse, open a novel, read, go to the next chapter and bookmark', (tester) async {
    final env = await TestEnv.create();
    await runCoreReadingFlow(tester, env);
    await env.dispose();
  });
}
