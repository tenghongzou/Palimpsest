import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/app.dart';
import 'package:palimpsest/core/database/database_helper.dart';
import 'package:palimpsest/core/database/offline_store.dart';
import 'package:palimpsest/core/network/api_client.dart';
import 'package:palimpsest/core/router/app_router.dart';
import 'package:palimpsest/features/auth/data/auth_repository.dart';
import 'package:palimpsest/features/auth/domain/entities/user.dart';
import 'package:palimpsest/features/auth/presentation/providers/auth_provider.dart';
import 'package:palimpsest/features/downloads/data/download_manager.dart';
import 'package:palimpsest/features/reader/data/reader_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_backend.dart';

/// Opens a fresh in-memory database with the shared schema. The no-isolate
/// factory completes through microtasks, so it works inside testWidgets.
Future<Database> openTestDatabase() {
  sqfliteFfiInit();
  return DatabaseHelper.open(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
}

/// Everything a widget test needs to run the real app against a fake server.
class TestEnv {
  final FakeBackend backend;
  final ApiClient api;
  final Database db;
  final User? user;

  TestEnv._(this.backend, this.api, this.db, this.user);

  /// [openDb] defaults to an in-memory FFI database; on a device the
  /// integration test passes the platform's sqflite factory instead.
  static Future<TestEnv> create({bool signedIn = true, Future<Database> Function()? openDb}) async {
    SharedPreferences.setMockInitialValues({});
    final backend = FakeBackend();
    final api = ApiClient(baseUrl: 'http://fake.test/api/v1', adapter: backend.api);
    User? user;
    if (signedIn) {
      api.setAccessToken('test-token');
      user = User.fromJson(userJson());
    }
    final db = await (openDb ?? openTestDatabase)();
    return TestEnv._(backend, api, db, user);
  }

  OfflineStore get store => OfflineStore(db);

  List<Override> get overrides => [
        apiClientProvider.overrideWithValue(api),
        offlineStoreProvider.overrideWithValue(() async => OfflineStore(db)),
        authStateProvider.overrideWith((ref) => AuthNotifier(
              ref.read(authRepositoryProvider),
              initialUser: user,
              beforeLogout: () => cleanUpBeforeLogout(ref),
            )),
        downloadManagerProvider.overrideWith((ref) => DownloadManager(
              reader: ref.read(readerRepositoryProvider),
              store: () async => OfflineStore(db),
              interval: Duration.zero,
            )),
      ];

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(overrides: overrides, child: const PalimpsestApp()));
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PalimpsestApp)));

  /// Navigates the running app to [location].
  Future<void> push(WidgetTester tester, String location) async {
    final container = ProviderScope.containerOf(tester.element(find.byType(PalimpsestApp)));
    container.read(appRouterProvider).push(location);
    await tester.pumpAndSettle();
  }

  /// Unmounts the app and lets work started by disposal (e.g. the reader's
  /// final progress report) finish, so no timers are left pending.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
  }

  Future<void> dispose() => db.close();
}

/// Pumps until [finder] matches or [timeout] of fake time passes.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = tester.binding.clock.now().add(timeout);
  while (finder.evaluate().isEmpty && tester.binding.clock.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Taps the reader content to show its toolbars.
Future<void> showReaderToolbar(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
  await tester.pumpAndSettle();
}
