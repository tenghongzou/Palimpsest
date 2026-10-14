import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  late TestEnv env;

  tearDown(() => env.dispose());

  Future<void> pickLanguage(WidgetTester tester, String option) async {
    final tile = find.byKey(const ValueKey('settings-language'));
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('language-$option')));
    await tester.pumpAndSettle();
  }

  Iterable<Object?> patchedLanguages() =>
      env.backend.api.calls('PATCH', '/users/me').map((r) => r.json['language_pref']);

  testWidgets('switching the language changes the UI at once and saves it to the account', (tester) async {
    env = await TestEnv.create();
    await env.pumpApp(tester);
    expect(find.text('首頁'), findsOneWidget);
    await env.push(tester, '/settings');
    expect(find.text('設定'), findsOneWidget);

    await pickLanguage(tester, 'en');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Reading settings'), findsOneWidget);
    expect(find.text('設定'), findsNothing);
    expect(patchedLanguages(), ['en']);
    expect(env.backend.me['language_pref'], 'en');

    await pickLanguage(tester, 'zh-CN');
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('阅读设置'), findsOneWidget);
    expect(patchedLanguages(), ['en', 'zh-CN']);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('编辑推荐'), findsOneWidget);

    // Following the system is local: nothing is sent.
    await env.push(tester, '/settings');
    await pickLanguage(tester, 'system');
    expect(patchedLanguages(), ['en', 'zh-CN']);
    await env.finish(tester);
  });

  testWidgets('a change the server rejects is reverted', (tester) async {
    env = await TestEnv.create();
    env.backend.profilePatchFailure = 500;
    await env.pumpApp(tester);
    await env.push(tester, '/settings');
    await pickLanguage(tester, 'en');
    expect(find.text('設定'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.textContaining('無法儲存語言設定'), findsOneWidget);
    await env.finish(tester);
  });

  testWidgets("a session start applies the account's language", (tester) async {
    env = await TestEnv.create(accountLanguage: 'en');
    await env.pumpApp(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text("Editor's picks"), findsOneWidget);
    await env.finish(tester);
  });

  testWidgets('following the system uses the device language and ignores the account', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ja', 'JP'), Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    env = await TestEnv.create(uiLanguage: 'system', accountLanguage: 'en');
    await env.pumpApp(tester);
    expect(find.text('首页'), findsOneWidget);

    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(patchedLanguages(), isEmpty);
    await env.finish(tester);
  });

  testWidgets('signed out: the choice stays on the device and is uploaded at sign-in', (tester) async {
    env = await TestEnv.create(signedIn: false);
    await env.pumpApp(tester);
    await env.push(tester, '/settings');
    await pickLanguage(tester, 'en');
    expect(find.text('Settings'), findsOneWidget);
    expect(patchedLanguages(), isEmpty);

    await env.push(tester, '/login');
    await tester.enterText(find.byType(TextFormField).at(0), 'reader1');
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(patchedLanguages(), ['en']);
    expect(find.text('Home'), findsOneWidget);
    await env.finish(tester);
  });

  testWidgets('dates and counts follow the UI language', (tester) async {
    env = await TestEnv.create(accountLanguage: 'en', uiLanguage: 'en');
    await env.pumpApp(tester);
    await env.push(tester, '/history');
    expect(find.text('Reading history'), findsOneWidget);
    expect(find.textContaining('just now'), findsOneWidget);
    expect(find.textContaining('read for 2 min'), findsOneWidget);
    await env.finish(tester);
  });
}
