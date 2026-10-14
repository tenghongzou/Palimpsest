import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/database/database_helper.dart';
import 'package:palimpsest/core/database/offline_store.dart';
import 'package:palimpsest/core/sync/sync_service.dart';
import 'package:palimpsest/features/reader/domain/entities/chapter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DioException httpError(int? status) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: status == null ? null : Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  late Database db;
  late OfflineStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await DatabaseHelper.open(databaseFactoryFfi, inMemoryDatabasePath);
    store = OfflineStore(db);
  });

  tearDown(() => db.close());

  Chapter chapter(String id, {String content = '內容'}) =>
      Chapter(id: id, novelId: 'n1', title: id, content: content, chapterNumber: 1, wordCount: content.length);

  group('OfflineStore', () {
    test('caches chapters and marks them as coming from the cache', () async {
      await store.saveChapter(chapter('c1', content: '鬥氣大陸'));
      final cached = await store.getChapter('c1');
      expect(cached?.content, '鬥氣大陸');
      expect(cached?.fromCache, isTrue);
      expect(await store.getChapter('missing'), isNull);
    });

    test('evicts the oldest chapters beyond the cache limit', () async {
      await db.update('local_meta', {'value': '10'}, where: 'key = ?', whereArgs: ['max_cache_size_bytes']);
      await store.saveChapter(chapter('old', content: 'aaaaaa'));
      await store.saveChapter(chapter('new', content: 'bbbbbb'));

      expect(await store.enforceCacheLimit(), 1);
      expect(await store.getChapter('old'), isNull);
      expect(await store.getChapter('new'), isNotNull);
    });

    test('keeps the most recently read progress', () async {
      await store.saveProgress(novelId: 'n1', chapterId: 'c2', scrollOffset: 1, readAt: DateTime.utc(2026, 10, 2));
      await store.saveProgress(novelId: 'n1', chapterId: 'c1', scrollOffset: 1, readAt: DateTime.utc(2026, 10, 1));
      expect((await store.getProgress('n1'))?['chapter_id'], 'c2');
    });

    test('keeps only the latest queued change per entity', () async {
      await store.enqueue('update', 'progress', 'n1', {'v': 1});
      await store.enqueue('update', 'progress', 'n2', {'v': 1});
      await store.enqueue('update', 'progress', 'n1', {'v': 2});
      final queue = await store.pendingQueue();
      expect(queue.map((q) => q.entityId), ['n2', 'n1']);
      expect(queue.last.payload, {'v': 2});
    });
  });

  group('SyncService', () {
    late List<SyncQueueItem> sent;
    late List<Object?> failures;

    SyncService service() => SyncService(
          store: () async => store,
          send: (item) async {
            if (failures.isNotEmpty) {
              final f = failures.removeAt(0);
              if (f != null) throw f;
            }
            sent.add(item);
          },
        );

    setUp(() {
      sent = [];
      failures = [];
    });

    test('records progress locally and uploads it', () async {
      final s = service();
      await s.recordProgress(novelId: 'n1', chapterId: 'c1');
      await s.pushPending();

      expect(sent.single.payload?['chapter_id'], 'c1');
      expect(await store.pendingQueue(), isEmpty);
      expect((await store.getProgress('n1'))?['is_synced'], 1);
    });

    test('stops at a network error and keeps the queue in order', () async {
      await store.enqueue('update', 'progress', 'n1', {'read_at': 'a'});
      await store.enqueue('update', 'progress', 'n2', {'read_at': 'b'});
      failures = [httpError(null)];

      expect(await service().pushPending(), 0);
      final queue = await store.pendingQueue();
      expect(queue.map((q) => q.entityId), ['n1', 'n2']);
      expect(queue.first.retryCount, 1);
    });

    test('drops changes the server permanently rejects', () async {
      await store.enqueue('update', 'progress', 'n1', {'read_at': 'a'});
      await store.enqueue('update', 'progress', 'n2', {'read_at': 'b'});
      failures = [httpError(400), null];

      expect(await service().pushPending(), 1);
      expect(await store.pendingQueue(), isEmpty);
    });
  });
}
