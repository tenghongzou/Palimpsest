import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/database/offline_store.dart';
import 'package:palimpsest/core/sync/sync_service.dart';
import 'package:palimpsest/core/utils/uuid.dart';
import 'package:palimpsest/features/reader/data/bookmark_repository.dart';
import 'package:palimpsest/features/reader/domain/entities/bookmark.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

void main() {
  late Database db;
  late OfflineStore store;
  late FakeBackend backend;
  late Dio dio;

  setUp(() async {
    db = await openTestDatabase();
    store = OfflineStore(db);
    backend = FakeBackend();
    dio = Dio(BaseOptions(baseUrl: 'http://fake.test/api/v1'))..httpClientAdapter = backend.api;
  });

  tearDown(() => db.close());

  Bookmark bookmark(String id, {String chapter = 'c', int paragraph = 0, String? note, bool synced = false}) => Bookmark(
        id: id,
        novelId: novelId,
        chapterId: chapter == 'c' ? chapterIds[0] : chapter,
        paragraphIndex: paragraph,
        note: note,
        createdAt: DateTime.utc(2026, 10, 14),
        isSynced: synced,
      );

  test('generateUuidV4 produces RFC 4122 v4 ids', () {
    final ids = List.generate(50, (_) => generateUuidV4());
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    }
    expect(ids.toSet(), hasLength(50));
  });

  group('syncBookmarks', () {
    test('uploads offline changes and adopts the server list', () async {
      await store.insertBookmark(bookmark('11111111-1111-4111-8111-111111111111', paragraph: 2, note: '伏筆'));
      await store.insertBookmark(bookmark('22222222-2222-4222-8222-222222222222'));
      await store.markBookmarkDeleted('22222222-2222-4222-8222-222222222222');
      // A bookmark made on another device.
      backend.bookmarks['33333333-3333-4333-8333-333333333333'] = {
        'id': '33333333-3333-4333-8333-333333333333',
        'novel_id': novelId,
        'chapter_id': chapterIds[1],
        'paragraph_index': 0,
        'created_at': '2026-10-13T00:00:00Z',
        'chapter': chapterJson(1, withContent: false),
      };

      await syncBookmarks(dio, store);

      final sent = backend.api.calls('POST', '/bookmarks/sync').single.json;
      expect((sent['upserts'] as List).single['id'], '11111111-1111-4111-8111-111111111111');
      expect((sent['upserts'] as List).single['note'], '伏筆');
      expect(sent['deletes'], ['22222222-2222-4222-8222-222222222222']);

      final local = await store.bookmarks();
      expect(local.map((b) => b.id).toSet(), {
        '11111111-1111-4111-8111-111111111111',
        '33333333-3333-4333-8333-333333333333',
      });
      expect(local.every((b) => b.isSynced), isTrue);
      expect(local.firstWhere((b) => b.id.startsWith('3')).chapterTitle, chapterTitles[1]);
      expect((await store.pendingBookmarkChanges()).deletes, isEmpty);
      expect(await store.getMeta('last_sync_at'), isNotNull);
    });

    test('removes synced bookmarks deleted on another device', () async {
      await store.insertBookmark(bookmark('44444444-4444-4444-8444-444444444444', synced: true));
      await syncBookmarks(dio, store);
      expect(await store.bookmarks(), isEmpty);
    });

    test('keeps local edits made while the sync was in flight', () async {
      final b = bookmark('55555555-5555-4555-8555-555555555555', note: 'old');
      await store.insertBookmark(b);
      // The server returns the version that was sent...
      await store.applyBookmarkSync(sentUpserts: [b], sentDeletes: const [], server: [b]);
      expect((await store.bookmarks()).single.isSynced, isTrue);

      // ...but if the note changed meanwhile, the local edit wins until the next sync.
      await store.updateBookmarkNote(b.id, 'new');
      await store.applyBookmarkSync(sentUpserts: [b], sentDeletes: const [], server: [b]);
      final local = (await store.bookmarks()).single;
      expect(local.note, 'new');
      expect(local.isSynced, isFalse);
    });

    test('splits large change sets into requests of at most 500', () async {
      for (var i = 0; i < 501; i++) {
        await store.insertBookmark(bookmark(generateUuidV4()));
      }
      await syncBookmarks(dio, store);
      final calls = backend.api.calls('POST', '/bookmarks/sync').toList();
      expect(calls, hasLength(2));
      expect((calls.first.json['upserts'] as List), hasLength(500));
      expect((calls.last.json['upserts'] as List), hasLength(1));
      expect((await store.bookmarks()), hasLength(501));
    });
  });

  group('BookmarkRepository', () {
    late SyncService sync;
    var signedIn = true;

    setUp(() {
      signedIn = true;
      sync = SyncService(
        store: () async => store,
        send: (item) => sendQueuedItem(dio, item, store: store),
        canPush: () => signedIn,
      );
    });

    test('works offline and syncs once signed in', () async {
      signedIn = false;
      final repo = BookmarkRepository(store: () async => store, sync: sync, isSignedIn: () => signedIn);
      final added = await repo.add(novelId: novelId, chapterId: chapterIds[0], chapterTitle: chapterTitles[0], paragraphIndex: 4);
      expect((await repo.list(novelId: novelId)).single.id, added.id);
      expect(backend.api.requests, isEmpty);

      signedIn = true;
      await repo.syncNow();
      expect(backend.bookmarks.keys, [added.id]);
      expect((await repo.list()).single.isSynced, isTrue);

      await repo.delete(added.id);
      await sync.pushPending();
      expect(backend.bookmarks, isEmpty);
      expect(await repo.list(), isEmpty);
    });
  });

  group('SyncService.recordProgress', () {
    test('adds up reading time not uploaded yet', () async {
      final sync = SyncService(store: () async => store, send: (_) async {}, canPush: () => false);
      await sync.recordProgress(novelId: novelId, chapterId: chapterIds[0], duration: 30, paragraphIndex: 2);
      await sync.recordProgress(novelId: novelId, chapterId: chapterIds[1], duration: 45, scrollOffset: 0.5);

      final queued = await store.pendingQueue();
      expect(queued, hasLength(1));
      expect(queued.single.payload?['duration'], 75);
      expect(queued.single.payload?['chapter_id'], chapterIds[1]);
      expect(queued.single.payload?['scroll_offset'], 0.5);
    });

    test('keeps progress local only when not uploading', () async {
      final sync = SyncService(store: () async => store, send: (_) async {});
      await sync.recordProgress(novelId: novelId, chapterId: chapterIds[0], upload: false);
      expect(await store.pendingQueue(), isEmpty);
      expect((await store.getProgress(novelId))?['chapter_id'], chapterIds[0]);
    });

    test('waits while signed out', () async {
      var sent = 0;
      var signedIn = false;
      final sync = SyncService(store: () async => store, send: (_) async => sent++, canPush: () => signedIn);
      await sync.recordProgress(novelId: novelId, chapterId: chapterIds[0]);
      expect(await sync.pushPending(), 0);
      expect(await store.pendingQueue(), hasLength(1));
      signedIn = true;
      expect(await sync.pushPending(), 1);
      expect(sent, 1);
    });
  });
}
