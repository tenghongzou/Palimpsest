import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:palimpsest/core/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/database/offline_store.dart';
import 'package:palimpsest/core/network/api_client.dart';
import 'package:palimpsest/features/bookshelf/data/bookshelf_repository.dart';
import 'package:palimpsest/features/bookstore/data/novel_repository.dart';
import 'package:palimpsest/features/community/data/community_repository.dart';
import 'package:palimpsest/features/profile/data/user_repository.dart';
import 'package:palimpsest/features/reader/data/reader_repository.dart';
import 'package:palimpsest/features/reader/domain/entities/chapter.dart';
import 'package:palimpsest/features/reader/domain/entities/reading_settings.dart';
import 'package:palimpsest/features/reader/presentation/widgets/translate_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_api.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

void main() {
  late FakeBackend backend;
  late ApiClient api;

  setUp(() {
    backend = FakeBackend();
    api = ApiClient(baseUrl: 'http://fake.test/api/v1', adapter: backend.api)..setAccessToken('t');
  });

  group('NovelRepository', () {
    test('sends the filters the API understands', () async {
      await NovelRepository(api).getNovelList(sortBy: 'popular', category: 'mystery', status: 'completed', page: 2);
      final q = backend.api.requests.last.query;
      expect(q['sort_by'], 'popular');
      expect(q['category'], 'mystery');
      expect(q['status'], 'completed');
      expect(q['page'], 2);
      expect(q.containsKey('sort'), isFalse);
    });

    test('rankings use the server pagination', () async {
      backend.api.on('GET', '/rankings/:type', (r) => FakeResponse.ok(page([novelJson()], page: 1, totalPages: 3)));
      final result = await NovelRepository(api).getRanking('views', period: 'monthly');
      expect(backend.api.requests.last.query['period'], 'monthly');
      expect(result.totalPages, 3);
      expect(result.hasMore, isTrue);
      expect(result.items.single.title, '霧港燈塔');
    });

    test('parses /home and categories', () async {
      final repo = NovelRepository(api);
      final home = await repo.getHome();
      expect(home.featured.single.categories, ['懸疑']);
      expect(home.latestUpdates.single.latestChapterId, chapterIds[2]);
      expect(home.newArrivals, isEmpty);
      final categories = await repo.getCategories();
      expect(categories.single.children.single.slug, 'oriental-fantasy');
    });
  });

  group('BookshelfRepository', () {
    test('uses sort_by and parses reading progress', () async {
      backend.api.on('GET', '/bookshelf', (_) => FakeResponse.ok([
            {
              'id': 's1',
              'novel_id': novelId,
              'group_name': '追更',
              'added_at': '2026-10-01T00:00:00Z',
              'novel': novelJson(),
              'has_update': true,
              'reading_progress': {
                'chapter_id': chapterIds[1],
                'chapter_title': chapterTitles[1],
                'chapter_number': 2,
                'percentage': 66.7,
                'read_at': '2026-10-13T00:00:00Z',
              },
            },
          ]));
      final items = await BookshelfRepository(api).getBookshelf(sortBy: 'title');
      expect(backend.api.requests.last.query, {'sort_by': 'title'});
      final item = items.single;
      expect(item.hasUpdate, isTrue);
      expect(item.groupName, '追更');
      expect(item.progress?.chapterId, chapterIds[1]);
      expect(item.progress?.percentage, 66.7);
      expect(item.addedAt, DateTime.utc(2026, 10, 1));
    });

    test('batch remove and group change', () async {
      backend.api
        ..on('POST', '/bookshelf/batch-remove', (_) => FakeResponse.ok(null))
        ..on('PATCH', '/bookshelf/:id', (r) => FakeResponse.ok({'group_name': r.json['group_name']}));
      final repo = BookshelfRepository(api);
      await repo.batchRemove(['a', 'b']);
      expect(backend.api.requests.last.json, {'novel_ids': ['a', 'b']});
      await repo.setGroup(novelId, '追更');
      expect(backend.api.requests.last.method, 'PATCH');
      expect(backend.api.requests.last.json, {'group_name': '追更'});
    });
  });

  group('ReaderRepository', () {
    late Database db;
    late ReaderRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = ReaderRepository(api, () async => OfflineStore(db));
    });

    tearDown(() => db.close());

    test('reads prev/next links and caches the chapter', () async {
      final chapter = await repo.getChapter(chapterIds[1]);
      expect(chapter.prevChapter?.id, chapterIds[0]);
      expect(chapter.nextChapter?.id, chapterIds[2]);
      expect(chapter.nextChapter?.title, chapterTitles[2]);
      expect(chapter.paragraphs, hasLength(3));
      expect(await OfflineStore(db).getChapter(chapterIds[1]), isNotNull);
    });

    test('offline it serves the cache with neighbours from stored chapters', () async {
      final store = OfflineStore(db);
      for (final i in [0, 2]) {
        await store.saveChapter(Chapter(
          id: chapterIds[i], novelId: novelId, title: chapterTitles[i], content: chapterContent(i), chapterNumber: i + 1,
        ));
      }
      await repo.getChapter(chapterIds[1]);
      backend.api.offline = true;

      final cached = await repo.getChapter(chapterIds[1]);
      expect(cached.fromCache, isTrue);
      expect(cached.prevChapter?.id, chapterIds[0]);
      expect(cached.nextChapter?.id, chapterIds[2]);

      final first = await repo.getChapter(chapterIds[0]);
      expect(first.prevChapter, isNull);
      expect(first.nextChapter?.id, chapterIds[1]);

      final toc = await repo.getToc(novelId);
      expect(toc.fromCache, isTrue);
      expect(toc.entries.map((e) => e.chapterNumber), [1, 2, 3]);
    });

    test('a server error is not treated as offline', () async {
      await expectLater(repo.getChapter('missing'), throwsA(isA<DioException>()));
    });

    test('translation: friendly 503 message and local cache', () async {
      try {
        await repo.translateChapter(chapterIds[1], 'en');
        fail('expected a 503');
      } catch (e) {
        expect(translationErrorMessage(e, 'en', lookupAppLocalizations(const Locale('zh', 'TW'))), contains('英文翻譯服務目前尚未開放'));
        expect(translationErrorMessage(e, 'en', lookupAppLocalizations(const Locale('en'))), contains("isn't available yet"));
      }

      final first = await repo.translateChapter(chapterIds[1], 'zh-CN');
      expect(first.title, '第二章 十点钟');
      expect(first.isCached, isFalse);
      final calls = backend.api.calls('POST', '/translation/chapter').length;
      final second = await repo.translateChapter(chapterIds[1], 'zh-CN');
      expect(second.isCached, isTrue);
      expect(second.content, first.content);
      expect(backend.api.calls('POST', '/translation/chapter').length, calls);
    });
  });

  group('CommunityRepository', () {
    test('reviews, likes, comments and reports hit the documented endpoints', () async {
      backend.api
        ..on('POST', '/novels/:id/reviews', (r) => FakeResponse.error(409, 40901, 'already reviewed'))
        ..on('POST', '/reviews/:id/like', (_) => FakeResponse.ok({'liked': true, 'like_count': 3}))
        ..on('DELETE', '/comments/:id/like', (_) => FakeResponse.ok({'liked': false, 'like_count': 0}))
        ..on('POST', '/reports', (r) => FakeResponse.ok({'id': 'r1', ...r.json}, status: 201));
      final repo = CommunityRepository(api);

      await expectLater(
        repo.createReview(novelId, title: 't', content: 'c', rating: 4.5),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 409)),
      );
      final like = await repo.setReviewLike('rev1', true);
      expect(like.liked, isTrue);
      expect(like.likeCount, 3);
      final unlike = await repo.setCommentLike('com1', false);
      expect(unlike.liked, isFalse);

      final comment = await repo.createComment(chapterIds[0], '好看', parentId: 'parent-1');
      expect(backend.api.requests.last.json, {'content': '好看', 'parent_id': 'parent-1'});
      expect(comment.content, '好看');
      final comments = await repo.getComments(chapterIds[0]);
      expect(comments.items.single.user?.nickname, '讀者一號');

      await repo.report(targetType: 'comment', targetId: 'com1', reason: 'spoiler', description: ' 劇透 ');
      expect(backend.api.requests.last.json, {
        'target_type': 'comment',
        'target_id': 'com1',
        'reason': 'spoiler',
        'description': '劇透',
      });
    });
  });

  group('UserRepository', () {
    test('stats, history, password and progress', () async {
      backend.api.on('PUT', '/users/me/password', (_) => FakeResponse.ok(null));
      final repo = UserRepository(api);
      final stats = await repo.getReadingStats(period: 'weekly');
      expect(backend.api.requests.last.query['period'], 'weekly');
      expect(stats.totalReadSeconds, 3600);
      expect(stats.buckets, hasLength(2));

      final history = await repo.getReadingHistory();
      expect(history.items.single.novel?.title, '霧港燈塔');
      expect(history.items.single.chapterNumber, 2);

      await repo.changePassword('old-pass', 'new-pass-123');
      expect(backend.api.requests.last.json, {'current_password': 'old-pass', 'new_password': 'new-pass-123'});

      expect(await repo.getProgress(novelId), isNull);
    });
  });

  group('ReadingSettings', () {
    test('toApiJson clamps to API ranges and maps legacy values', () {
      const s = ReadingSettings(
        fontSize: 40,
        lineHeight: 0.5,
        letterSpacing: -1,
        margin: 100,
        theme: 'yellow',
        readingMode: 'paged',
        brightness: 0,
      );
      final json = s.toApiJson();
      expect(json['font_size'], 36);
      expect(json['line_height'], 1.2);
      expect(json['letter_spacing'], 0.0);
      expect(json['margin'], 64);
      expect(json['theme'], 'sepia');
      expect(json['reading_mode'], 'page');
      expect(json['brightness'], 10);
      expect(json.keys, containsAll(['keep_screen_on', 'auto_chapter', 'font_family']));
    });
  });
}
