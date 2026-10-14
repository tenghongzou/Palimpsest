import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/network/api_client.dart';
import 'package:palimpsest/core/network/api_error.dart';
import 'package:palimpsest/features/bookshelf/data/bookshelf_repository.dart';
import 'package:palimpsest/features/bookshelf/presentation/providers/bookshelf_provider.dart';
import 'package:palimpsest/features/community/data/community_repository.dart';
import 'package:palimpsest/features/devices/data/device_registration.dart';
import 'package:palimpsest/features/devices/data/device_repository.dart';
import 'package:palimpsest/features/notifications/data/notification_repository.dart';
import 'package:palimpsest/features/notifications/presentation/providers/notification_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late ApiClient api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    api = ApiClient(baseUrl: 'http://fake.test/api/v1', adapter: backend.api)..setAccessToken('t');
  });

  group('NotificationRepository', () {
    test('lists with pagination and unread_only, counts, marks and deletes', () async {
      backend.notifications.addAll([
        notificationJson('a', title: 'A'),
        notificationJson('b', title: 'B', read: true),
      ]);
      final repo = NotificationRepository(api);

      final all = await repo.list(page: 1, pageSize: 10);
      expect(all.items.map((n) => n.title), ['A', 'B']);
      expect(backend.api.requests.last.query, {'page': 1, 'page_size': 10});

      final unread = await repo.list(unreadOnly: true);
      expect(unread.items.single.id, 'a');
      expect(backend.api.requests.last.query['unread_only'], true);

      expect(await repo.unreadCount(), 1);
      await repo.markRead('a');
      expect(await repo.unreadCount(), 0);

      backend.notifications.add(notificationJson('c', title: 'C'));
      expect(await repo.markAllRead(), 1);

      await repo.delete('b');
      expect(backend.notifications.map((n) => n['id']), ['a', 'c']);
    });
  });

  group('UnreadCountNotifier', () {
    test('refreshes, keeps the last count when offline, and resets', () async {
      backend.notifications.addAll([notificationJson('a'), notificationJson('b')]);
      final notifier = UnreadCountNotifier(NotificationRepository(api), isSignedIn: () => true);
      await notifier.refresh();
      expect(notifier.state, 2);

      backend.api.offline = true;
      await notifier.refresh();
      expect(notifier.state, 2);

      notifier
        ..decrement()
        ..decrement()
        ..decrement();
      expect(notifier.state, 0);

      notifier
        ..set(5)
        ..startPolling();
      expect(notifier.isPolling, isTrue);
      notifier.reset();
      expect(notifier.state, 0);
      expect(notifier.isPolling, isFalse);
      notifier.dispose();
    });

    test('signed out: zero without asking', () async {
      final notifier = UnreadCountNotifier(NotificationRepository(api), isSignedIn: () => false)..set(3);
      await notifier.refresh();
      expect(notifier.state, 0);
      expect(backend.api.requests, isEmpty);
      notifier.dispose();
    });
  });

  group('DeviceRegistration', () {
    test('registers once per user and launch, then removes its record', () async {
      final reg = DeviceRegistration(DeviceRepository(api), DeviceIdentity());
      await reg.ensureRegistered(userId);
      await reg.ensureRegistered(userId);
      expect(backend.api.calls('POST', '/users/me/devices'), hasLength(1));
      expect(reg.recordId, backend.devices.keys.single);

      // Another account on the same install registers again.
      await reg.ensureRegistered('another-user');
      expect(backend.api.calls('POST', '/users/me/devices'), hasLength(2));

      await reg.unregister();
      expect(backend.devices, isEmpty);
      expect(reg.recordId, isNull);
    });

    test('a failed registration is retried and does not throw', () async {
      final reg = DeviceRegistration(DeviceRepository(api), DeviceIdentity());
      backend.api.offline = true;
      await reg.ensureRegistered(userId);
      expect(reg.recordId, isNull);
      backend.api.offline = false;
      await reg.ensureRegistered(userId);
      expect(reg.recordId, isNotNull);
    });

    test('unregister finds the record by device id when not registered this launch', () async {
      final identity = DeviceIdentity();
      await DeviceRegistration(DeviceRepository(api), identity).ensureRegistered(userId);
      final fresh = DeviceRegistration(DeviceRepository(api), identity);
      await fresh.unregister();
      expect(backend.devices, isEmpty);
    });

    test('passes the push token when one is supplied', () async {
      final reg = DeviceRegistration(DeviceRepository(api), DeviceIdentity(), pushToken: () async => 'fcm-token');
      await reg.ensureRegistered(userId);
      expect(backend.api.calls('POST', '/users/me/devices').single.json['push_token'], 'fcm-token');
    });
  });

  group('paragraph comments', () {
    test('parses counts and filters comments by paragraph', () async {
      backend.comments.addAll([
        commentJson('c1', 'one', paragraphIndex: 0),
        commentJson('c2', 'two', paragraphIndex: 2),
        commentJson('c3', 'three', paragraphIndex: 2),
        commentJson('c4', 'chapter'),
      ]);
      final repo = CommunityRepository(api);
      expect(await repo.getParagraphCounts(chapterIds[0]), {0: 1, 2: 2});

      final onTwo = await repo.getComments(chapterIds[0], paragraphIndex: 2);
      expect(onTwo.items.map((c) => c.id), ['c2', 'c3']);
      expect(backend.api.requests.last.query['paragraph_index'], 2);

      await repo.getComments(chapterIds[0]);
      expect(backend.api.requests.last.query.containsKey('paragraph_index'), isFalse);
    });

    test('fetches a whole thread by its top-level or reply id; 404 when gone', () async {
      backend.comments.add(commentJson('t1', 'thread', paragraphIndex: 1, replies: [
        commentJson('r1', 'reply', parentId: 't1'),
      ]));
      final repo = CommunityRepository(api);
      for (final id in ['t1', 'r1']) {
        final thread = await repo.getCommentThread(id);
        expect(thread.id, 't1');
        expect(thread.paragraphIndex, 1);
        expect(thread.replies.single.id, 'r1');
      }
      await expectLater(
        repo.getCommentThread('missing'),
        throwsA(predicate((e) => httpStatus(e!) == 404 && apiErrorCode(e) == 40405)),
      );
    });

        test('parseParagraphCounts ignores malformed entries', () {
      expect(
        CommunityRepository.parseParagraphCounts([
          {'paragraph_index': 1, 'count': 3},
          {'paragraph_index': -1, 'count': 1},
          {'paragraph_index': 4, 'count': 0},
          {'count': 2},
          'nonsense',
        ]),
        {1: 3},
      );
      expect(CommunityRepository.parseParagraphCounts(null), isEmpty);
    });
  });

  group('bookshelf update notifications', () {
    test('parses is_notified, defaulting to on', () {
      final base = {'id': 's', 'novel_id': novelId, 'added_at': '2026-10-01T00:00:00Z'};
      expect(BookshelfRepository.parseItem(base).isNotified, isTrue);
      expect(BookshelfRepository.parseItem({...base, 'is_notified': false}).isNotified, isFalse);
    });

    test('PATCH sends only the given fields', () async {
      backend.bookshelf.add(novelId);
      final repo = BookshelfRepository(api);
      await repo.updateItem(novelId, isNotified: false);
      expect(backend.api.requests.last.json, {'is_notified': false});
      await repo.setGroup(novelId, '追更');
      expect(backend.api.requests.last.json, {'group_name': '追更'});
    });

    test('setNotified is optimistic and rolls back on failure', () async {
      backend.bookshelf.add(novelId);
      final notifier = BookshelfNotifier(BookshelfRepository(api));
      await notifier.load();
      expect(notifier.state.value!.single.isNotified, isTrue);

      await notifier.setNotified(novelId, false);
      expect(notifier.state.value!.single.isNotified, isFalse);
      expect(backend.bookshelfMuted, {novelId});

      backend.bookshelfPatchFailure = 500;
      await expectLater(notifier.setNotified(novelId, true), throwsA(anything));
      expect(notifier.state.value!.single.isNotified, isFalse);
      notifier.dispose();
    });
  });
}
