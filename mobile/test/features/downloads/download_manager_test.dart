import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/database/offline_store.dart';
import 'package:palimpsest/core/network/api_client.dart';
import 'package:palimpsest/features/bookstore/domain/entities/novel.dart';
import 'package:palimpsest/features/downloads/data/download_manager.dart';
import 'package:palimpsest/features/reader/data/reader_repository.dart';
import 'package:palimpsest/features/reader/domain/entities/chapter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/fake_api.dart';
import '../../support/fake_backend.dart';
import '../../support/test_app.dart';

void main() {
  late Database db;
  late OfflineStore store;
  late FakeBackend backend;
  late List<Duration> waits;
  late DownloadManager manager;

  setUp(() async {
    db = await openTestDatabase();
    store = OfflineStore(db);
    backend = FakeBackend();
    waits = [];
    final api = ApiClient(baseUrl: 'http://fake.test/api/v1', adapter: backend.api);
    manager = DownloadManager(
      reader: ReaderRepository(api, () async => store),
      store: () async => store,
      interval: const Duration(milliseconds: 700),
      wait: (d) async => waits.add(d),
    );
  });

  tearDown(() async {
    manager.dispose();
    await db.close();
  });

  final novel = Novel.fromJson(novelJson());

  Future<DownloadTask> finished() async {
    for (var i = 0; i < 200; i++) {
      final task = manager.task(novelId);
      if (task != null && !task.isActive) return task;
      await Future<void>.delayed(Duration.zero);
    }
    fail('download did not finish');
  }

  test('downloads every chapter sequentially with spacing between requests', () async {
    manager.download(novel);
    final task = await finished();

    expect(task.status, DownloadStatus.completed);
    expect(task.done, 3);
    expect(task.total, 3);
    expect(backend.api.calls('GET', '/chapters/').map((r) => r.params['id']), chapterIds);
    expect(waits, [const Duration(milliseconds: 700), const Duration(milliseconds: 700)]);
    expect(await store.downloadedChapterIds(novelId), chapterIds.toSet());

    final downloaded = (await store.downloadedNovels()).single;
    expect(downloaded.title, '霧港燈塔');
    expect(downloaded.isComplete, isTrue);
    expect(downloaded.sizeBytes, greaterThan(0));
  });

  test('skips chapters already downloaded', () async {
    await store.saveChapter(
      Chapter(id: chapterIds[0], novelId: novelId, title: chapterTitles[0], content: 'x', chapterNumber: 1),
      downloaded: true,
    );
    manager.download(novel);
    await finished();
    expect(backend.api.calls('GET', '/chapters/').map((r) => r.params['id']), chapterIds.skip(1));
  });

  test('waits for Retry-After on 429 and retries', () async {
    var limited = true;
    backend.api.on('GET', '/chapters/:id', (r) {
      if (limited && r.params['id'] == chapterIds[1]) {
        limited = false;
        return FakeResponse.error(429, 42901, 'slow down', headers: {
          'retry-after': ['7'],
        });
      }
      return FakeResponse.ok(chapterJson(chapterIds.indexOf(r.params['id']!)));
    });
    manager.download(novel);
    final task = await finished();
    expect(task.status, DownloadStatus.completed);
    expect(waits, contains(const Duration(seconds: 7)));
    expect(await store.downloadedChapterIds(novelId), hasLength(3));
  });

  test('fails with a message when offline', () async {
    backend.api.offline = true;
    manager.download(novel);
    final task = await finished();
    expect(task.status, DownloadStatus.failed);
    expect(task.error, isNotNull);
  });

  test('reading cache is evictable but downloads are not', () async {
    await store.saveChapter(
      const Chapter(id: 'read', novelId: novelId, title: 't', content: 'aaaaaaaaaa', chapterNumber: 9),
    );
    await store.saveChapter(
      const Chapter(id: 'dl', novelId: novelId, title: 't', content: 'bbbbbbbbbb', chapterNumber: 10),
      downloaded: true,
    );
    await store.setMeta('max_cache_size_bytes', '5');
    expect(await store.enforceCacheLimit(), 1);
    expect(await store.getChapter('read'), isNull);
    expect(await store.getChapter('dl'), isNotNull);

    // Reading a downloaded chapter again keeps it downloaded.
    await store.saveChapter(const Chapter(id: 'dl', novelId: novelId, title: 't', content: 'bbbbbbbbbb', chapterNumber: 10));
    expect(await store.downloadedChapterIds(novelId), {'dl'});

    await store.deleteDownloadedNovel(novelId);
    expect(await store.downloadedNovels(), isEmpty);
  });
}
