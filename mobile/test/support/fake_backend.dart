import 'fake_api.dart';

/// Seed data shaped like the real API (see shared/api-spec/openapi.yaml).
const novelId = '6a82ecb0-0864-4090-9afa-c2ce0a2e9a7f';
const chapterIds = [
  '2cc78024-d090-47da-b88d-9dd4df9ca8e4',
  '72b1fa69-3acc-4f61-a914-51f3cea151b3',
  '590b42ac-52c4-4fb9-ac97-8be2e5f57e2c',
];
const chapterTitles = ['第一章 無名的信', '第二章 十點鐘', '第三章 沒有旗的船'];
const userId = '7857f9f7-c96e-431a-9866-efa064b5a454';

Map<String, dynamic> novelJson() => {
      'id': novelId,
      'title': '霧港燈塔',
      'author_name': '林硯',
      'description': '海霧終年不散的港口，燈塔看守人每晚都會收到一封沒有寄件人的信。',
      'status': 'ongoing',
      'language': 'zh-TW',
      'total_words': 281,
      'total_chapters': 3,
      'view_count': 6,
      'favorite_count': 0,
      'review_count': 0,
      'avg_rating': 4.5,
      'latest_chapter_id': chapterIds[2],
      'latest_chapter_title': chapterTitles[2],
      'categories': [
        {'id': 11, 'name': '懸疑', 'slug': 'mystery'},
      ],
      'tags': [
        {'id': 1, 'name': '海港'},
      ],
    };

String chapterContent(int i) => '第${i + 1}章的第一段。\n\n第${i + 1}章的第二段。\n\n第${i + 1}章的第三段。';

Map<String, dynamic> chapterRef(int i) => {'id': chapterIds[i], 'title': chapterTitles[i], 'chapter_number': i + 1};

Map<String, dynamic> chapterJson(int i, {bool withContent = true}) => {
      'id': chapterIds[i],
      'novel_id': novelId,
      'title': chapterTitles[i],
      if (withContent) 'content': chapterContent(i),
      'chapter_number': i + 1,
      'word_count': 30,
      'is_published': true,
      'is_free': true,
      if (withContent) 'prev_chapter': i > 0 ? chapterRef(i - 1) : null,
      if (withContent) 'next_chapter': i < chapterIds.length - 1 ? chapterRef(i + 1) : null,
    };

Map<String, dynamic> userJson() => {
      'id': userId,
      'username': 'reader1',
      'email': 'reader1@example.com',
      'nickname': '讀者一號',
      'role': 'reader',
      'status': 'active',
      'language_pref': 'zh-TW',
      'total_read_words': 1200,
      'total_read_seconds': 3600,
    };

Map<String, dynamic> page(List<Object?> items, {int page = 1, int totalPages = 1}) => {
      'items': items,
      'pagination': {'page': page, 'page_size': 20, 'total': items.length, 'total_pages': totalPages},
    };

/// A stateful fake of the backend for widget and integration tests.
class FakeBackend {
  final FakeApi api = FakeApi();
  final Map<String, Map<String, dynamic>> bookmarks = {};
  final List<Map<String, dynamic>> comments = [];
  final List<Map<String, dynamic>> progressUpdates = [];
  final Set<String> bookshelf = {};

  /// Set to make POST /bookshelf fail with this status.
  int? bookshelfFailure;

  FakeBackend() {
    api
      ..on('GET', '/home', (_) => FakeResponse.ok({
            'banners': [],
            'featured': [novelJson()],
            'latest_updates': [novelJson()],
            'popular': [novelJson()],
            'new_arrivals': [],
            'completed': [],
          }))
      ..on('GET', '/novels', (_) => FakeResponse.ok(page([novelJson()])))
      ..on('GET', '/novels/:id', (r) => r.params['id'] == novelId
          ? FakeResponse.ok(novelJson())
          : FakeResponse.error(404, 40401, 'novel not found'))
      ..on('GET', '/novels/:id/chapters', (_) =>
          FakeResponse.ok([for (var i = 0; i < chapterIds.length; i++) chapterJson(i, withContent: false)]))
      ..on('GET', '/chapters/:id', (r) {
        final i = chapterIds.indexOf(r.params['id']!);
        return i < 0 ? FakeResponse.error(404, 40402, 'chapter not found') : FakeResponse.ok(chapterJson(i));
      })
      ..on('GET', '/categories', (_) => FakeResponse.ok([
            {
              'id': 1,
              'name': '玄幻',
              'slug': 'xuanhuan',
              'children': [
                {'id': 2, 'parent_id': 1, 'name': '東方玄幻', 'slug': 'oriental-fantasy'},
              ],
            },
          ]))
      ..on('GET', '/rankings/:type', (r) => FakeResponse.ok(page([novelJson()])))
      ..on('GET', '/novels/:id/reviews', (_) => FakeResponse.ok(page([])))
      ..on('GET', '/chapters/:id/comments', (r) => FakeResponse.ok(page(
            comments.where((c) => c['chapter_id'] == r.params['id']).toList(),
          )))
      ..on('POST', '/chapters/:id/comments', (r) {
        final comment = {
          'id': 'c0mment0-0000-4000-8000-00000000000${comments.length}',
          'user_id': userId,
          'chapter_id': r.params['id'],
          'content': r.json['content'],
          'like_count': 0,
          'liked_by_me': false,
          'user': {'id': userId, 'username': 'reader1', 'nickname': '讀者一號'},
          'replies': [],
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        comments.add(comment);
        return FakeResponse.ok(comment, status: 201);
      })
      ..on('GET', '/reading-progress/:id', (_) => FakeResponse.error(404, 40404, 'no progress'))
      ..on('PUT', '/reading-progress/:id', (r) {
        progressUpdates.add({'novel_id': r.params['id'], ...r.json});
        return FakeResponse.ok({'novel_id': r.params['id'], ...r.json});
      })
      ..on('POST', '/bookmarks/sync', (r) {
        for (final u in (r.json['upserts'] as List? ?? const [])) {
          final m = (u as Map).cast<String, dynamic>();
          final i = chapterIds.indexOf(m['chapter_id'] as String);
          bookmarks[m['id'] as String] = {
            ...m,
            'user_id': userId,
            'novel_id': novelId,
            'chapter': i < 0 ? null : chapterJson(i, withContent: false),
          };
        }
        for (final id in (r.json['deletes'] as List? ?? const [])) {
          bookmarks.remove(id);
        }
        return FakeResponse.ok(bookmarks.values.toList());
      })
      ..on('GET', '/bookshelf', (_) => FakeResponse.ok(bookshelf
          .map((id) => {
                'id': 'shelf-$id',
                'novel_id': id,
                'group_name': 'default',
                'novel': novelJson(),
                'reading_progress': null,
                'has_update': false,
              })
          .toList()))
      ..on('POST', '/bookshelf', (r) {
        final failure = bookshelfFailure;
        if (failure != null) return FakeResponse.error(failure, 50001, 'boom');
        bookshelf.add(r.json['novel_id'] as String);
        return FakeResponse.ok({'id': 'shelf', 'novel_id': r.json['novel_id']}, status: 201);
      })
      ..on('POST', '/translation/chapter', (r) => r.json['target_lang'] == 'en'
          ? FakeResponse.error(503, 50301, 'machine translation is not available')
          : FakeResponse.ok({
              'chapter_id': r.json['chapter_id'],
              'original_lang': 'zh-TW',
              'target_lang': r.json['target_lang'],
              'translated_title': '第二章 十点钟',
              'translated_content': '简体的第一段。\n\n简体的第二段。',
              'is_cached': false,
            }))
      ..on('GET', '/users/me', (_) => FakeResponse.ok(userJson()))
      ..on('GET', '/users/me/reading-settings', (_) => FakeResponse.ok({
            'font_size': 18,
            'line_height': 1.8,
            'theme': 'white',
            'reading_mode': 'scroll',
            'brightness': 100,
            'updated_at': '0001-01-01T00:00:00Z',
          }))
      ..on('PUT', '/users/me/reading-settings', (r) => FakeResponse.ok(r.json))
      ..on('GET', '/users/me/reading-stats', (r) => FakeResponse.ok({
            'total_read_words': 1200,
            'total_read_seconds': 3600,
            'chapters_read': 4,
            'novels_read': 1,
            'period': r.query['period'] ?? 'daily',
            'buckets': [
              {'start': '2026-10-13T00:00:00Z', 'chapters': 1, 'words': 100, 'seconds': 600},
              {'start': '2026-10-14T00:00:00Z', 'chapters': 3, 'words': 1100, 'seconds': 3000},
            ],
          }))
      ..on('GET', '/reading-history', (_) => FakeResponse.ok(page([
            {
              'id': 'h1',
              'novel_id': novelId,
              'chapter_id': chapterIds[1],
              'read_at': DateTime.now().toUtc().toIso8601String(),
              'duration': 120,
              'novel': novelJson(),
              'chapter': chapterJson(1, withContent: false),
            },
          ])))
      ..on('POST', '/auth/forgot-password', (_) => FakeResponse.ok({'message': 'ok'}))
      ..on('GET', '/search/hot-keywords', (_) => FakeResponse.ok(['燈塔']));
  }
}
