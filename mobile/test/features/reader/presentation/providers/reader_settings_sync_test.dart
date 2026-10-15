import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/database/offline_store.dart';
import 'package:palimpsest/core/network/api_client.dart';
import 'package:palimpsest/features/reader/domain/entities/reading_settings.dart';
import 'package:palimpsest/features/reader/presentation/providers/reader_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../support/fake_api.dart';
import '../../../../support/fake_backend.dart';
import '../../../../support/test_app.dart';

void main() {
  late Database db;
  late OfflineStore store;
  late FakeBackend backend;
  late ApiClient api;

  setUp(() async {
    db = await openTestDatabase();
    store = OfflineStore(db);
    backend = FakeBackend();
    api = ApiClient(baseUrl: 'http://fake.test/api/v1', adapter: backend.api)..setAccessToken('t');
  });

  tearDown(() => db.close());

  ReaderSettingsNotifier notifier({bool signedIn = true}) => ReaderSettingsNotifier(
        store: () async => store,
        remote: ReadingSettingsRemote(api),
        isSignedIn: () => signedIn,
      );

  test('persists locally and reloads', () async {
    final a = notifier(signedIn: false)..updateFontSize(24);
    a.updateTheme('dark');
    await Future<void>.delayed(Duration.zero);
    final b = notifier(signedIn: false);
    await b.loadFromLocal();
    expect(b.state.fontSize, 24);
    expect(b.state.theme, 'dark');
    a.dispose();
    b.dispose();
  });

  test('applies newer server settings', () async {
    await store.saveReadingSettings(const ReadingSettings(fontSize: 20), updatedAt: DateTime.utc(2026, 1, 1));
    backend.api.on('GET', '/users/me/reading-settings', (_) => FakeResponse.ok({
          'font_size': 28,
          'line_height': 2.0,
          'theme': 'green',
          'reading_mode': 'scroll',
          'brightness': 80,
          'updated_at': '2026-10-01T00:00:00Z',
        }));
    final n = notifier();
    await n.loadFromLocal();
    await n.syncWithServer();
    expect(n.state.fontSize, 28);
    expect(n.state.theme, 'green');
    expect((await store.loadReadingSettings())!.$1.fontSize, 28);
    expect(backend.api.calls('PUT', '/users/me/reading-settings'), isEmpty);
    n.dispose();
  });

  test('uploads local settings when they are newer', () async {
    await store.saveReadingSettings(const ReadingSettings(fontSize: 22, theme: 'sepia'));
    final n = notifier();
    await n.loadFromLocal();
    await n.syncWithServer();
    final put = backend.api.calls('PUT', '/users/me/reading-settings').single.json;
    expect(put['font_size'], 22);
    expect(put['theme'], 'sepia');
    n.dispose();
  });

  test('debounces uploads of changes', () async {
    final n = notifier();
    n.updateFontSize(20);
    n.updateFontSize(21);
    n.updateFontSize(22);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(backend.api.calls('PUT', '/users/me/reading-settings'), isEmpty);
    await Future<void>.delayed(ReaderSettingsNotifier.pushDelay + const Duration(milliseconds: 300));
    final puts = backend.api.calls('PUT', '/users/me/reading-settings').toList();
    expect(puts, hasLength(1));
    expect(puts.single.json['font_size'], 22);
    n.dispose();
  });

  group('page animation', () {
    test('is persisted locally and uploaded with the other settings', () async {
      final a = notifier()..updatePageAnimation('cover');
      await Future<void>.delayed(ReaderSettingsNotifier.pushDelay + const Duration(milliseconds: 300));
      expect(backend.api.calls('PUT', '/users/me/reading-settings').last.json['page_animation'], 'cover');
      final b = notifier(signedIn: false);
      await b.loadFromLocal();
      expect(b.state.pageAnimation, 'cover');
      a.dispose();
      b.dispose();
    });

    test('is applied from the server', () async {
      backend.api.on('GET', '/users/me/reading-settings', (_) => FakeResponse.ok({
            'font_size': 18,
            'line_height': 1.8,
            'theme': 'white',
            'reading_mode': 'page',
            'page_animation': 'none',
            'brightness': 100,
            'updated_at': '2026-10-01T00:00:00Z',
          }));
      final n = notifier();
      await n.syncWithServer();
      expect(n.state.pageAnimation, 'none');
      expect(n.state.effectivePageAnimation, 'none');
      n.dispose();
    });

    test('a server-side curl is used as is and kept when other settings change', () async {
      backend.api.on('GET', '/users/me/reading-settings', (_) => FakeResponse.ok({
            'font_size': 18,
            'line_height': 1.8,
            'theme': 'white',
            'reading_mode': 'page',
            'page_animation': 'curl',
            'brightness': 100,
            'updated_at': '2026-10-01T00:00:00Z',
          }));
      final n = notifier();
      await n.syncWithServer();
      expect(n.state.pageAnimation, 'curl');
      expect(n.state.effectivePageAnimation, 'curl');

      n.updateFontSize(22);
      await Future<void>.delayed(ReaderSettingsNotifier.pushDelay + const Duration(milliseconds: 300));
      final put = backend.api.calls('PUT', '/users/me/reading-settings').last.json;
      expect(put['font_size'], 22);
      expect(put['page_animation'], 'curl');
      n.dispose();
    });

    test('an unknown server-side animation shows as slide and is not overwritten by other changes', () async {
      backend.api.on('GET', '/users/me/reading-settings', (_) => FakeResponse.ok({
            'font_size': 18,
            'line_height': 1.8,
            'theme': 'white',
            'reading_mode': 'page',
            'page_animation': 'fold3d',
            'brightness': 100,
            'updated_at': '2026-10-01T00:00:00Z',
          }));
      final n = notifier();
      await n.syncWithServer();
      expect(n.state.pageAnimation, 'fold3d');
      expect(n.state.effectivePageAnimation, 'slide');

      n.updateFontSize(22);
      await Future<void>.delayed(ReaderSettingsNotifier.pushDelay + const Duration(milliseconds: 300));
      final put = backend.api.calls('PUT', '/users/me/reading-settings').last.json;
      expect(put['font_size'], 22);
      expect(put.containsKey('page_animation'), isFalse);

      // Picking one here does send it.
      n.updatePageAnimation('slide');
      await Future<void>.delayed(ReaderSettingsNotifier.pushDelay + const Duration(milliseconds: 300));
      expect(backend.api.calls('PUT', '/users/me/reading-settings').last.json['page_animation'], 'slide');
      n.dispose();
    });
  });
}
