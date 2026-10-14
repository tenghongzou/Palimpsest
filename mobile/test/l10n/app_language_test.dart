import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/auth/domain/entities/user.dart';
import 'package:palimpsest/features/profile/presentation/providers/app_language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

User _user(String pref) => User(id: 'u', username: 'u', email: '', nickname: 'u', languagePref: pref);

void main() {
  late List<String> saved;
  late List<User> updated;
  late bool signedIn;
  Object? failWith;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    saved = [];
    updated = [];
    signedIn = true;
    failWith = null;
  });

  AppLanguageNotifier notifier(AppLanguage initial) => AppLanguageNotifier(
        initial: initial,
        saveToAccount: (code) async {
          saved.add(code);
          if (failWith != null) throw failWith!;
          return _user(code);
        },
        isSignedIn: () => signedIn,
        onUserUpdated: updated.add,
      );

  DioException serverError() => DioException(
        requestOptions: RequestOptions(path: '/users/me'),
        response: Response(requestOptions: RequestOptions(path: '/users/me'), statusCode: 500),
      );

  DioException offline() => DioException.connectionError(requestOptions: RequestOptions(path: '/users/me'), reason: 'x');

  test('defaults to following the system and persists choices', () async {
    expect((await AppLanguage.load()).followsSystem, isTrue);
    signedIn = false;
    final n = notifier(const AppLanguage(followSystemLanguage));
    await n.select('en');
    expect(n.state, const AppLanguage('en', pendingUpload: true));
    expect(n.state.locale?.languageCode, 'en');
    await Future<void>.delayed(Duration.zero);
    expect(await AppLanguage.load(), const AppLanguage('en', pendingUpload: true));
    await n.select(followSystemLanguage);
    expect(n.state.locale, isNull);
    await Future<void>.delayed(Duration.zero);
    expect((await AppLanguage.load()).followsSystem, isTrue);
    expect(saved, isEmpty);
  });

  test('signed in: applies at once and saves to the account', () async {
    final n = notifier(const AppLanguage('zh-TW'));
    final result = await n.select('zh-CN');
    expect(result, LanguageChange.applied);
    expect(n.state, const AppLanguage('zh-CN'));
    expect(saved, ['zh-CN']);
    expect(updated.single.languagePref, 'zh-CN');
  });

  test('signed in: a rejected change is reverted', () async {
    failWith = serverError();
    final n = notifier(const AppLanguage('zh-TW'));
    final pending = n.select('en');
    // Optimistic: shown before the server answers.
    expect(n.state.setting, 'en');
    expect(await pending, LanguageChange.reverted);
    expect(n.state, const AppLanguage('zh-TW'));
  });

  test('signed in but offline: kept and uploaded at the next session start', () async {
    failWith = offline();
    final n = notifier(const AppLanguage('zh-TW'));
    expect(await n.select('en'), LanguageChange.savedLater);
    expect(n.state, const AppLanguage('en', pendingUpload: true));
    failWith = null;
    await n.syncWithAccount(_user('zh-TW'));
    expect(saved, ['en', 'en']);
    expect(n.state, const AppLanguage('en'));
  });

  test('following the system is local: no request, and the account does not override it', () async {
    final n = notifier(const AppLanguage('zh-TW'));
    await n.select(followSystemLanguage);
    expect(saved, isEmpty);
    await n.syncWithAccount(_user('en'));
    expect(n.state.followsSystem, isTrue);
    expect(saved, isEmpty);
  });

  test("a session start applies the account's language", () async {
    final n = notifier(const AppLanguage('zh-TW'));
    await n.syncWithAccount(_user('zh-CN'));
    expect(n.state, const AppLanguage('zh-CN'));
    expect(saved, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(await AppLanguage.load(), const AppLanguage('zh-CN'));
  });

  test('a language picked while signed out is uploaded at sign-in instead', () async {
    signedIn = false;
    final n = notifier(const AppLanguage('zh-TW'));
    await n.select('en');
    signedIn = true;
    await n.syncWithAccount(_user('zh-TW'));
    expect(saved, ['en']);
    expect(n.state, const AppLanguage('en'));
    expect(updated.single.languagePref, 'en');
  });
}
