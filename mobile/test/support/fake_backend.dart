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

/// A `Notification` as the API returns it.
Map<String, dynamic> notificationJson(
  String id, {
  String type = 'system',
  String title = '系統公告',
  String? body,
  String? chapterId,
  String? commentId,
  bool read = false,
  DateTime? createdAt,
  Map<String, String>? params,
}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      if (body != null) 'body': body,
      if (chapterId != null) 'novel_id': novelId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (commentId != null) 'comment_id': commentId,
      'read_at': read ? '2026-10-13T08:00:00Z' : null,
      'created_at': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
      if (params != null) 'params': params,
    };

/// A top-level comment (optionally on a paragraph) with [replies]; [status]
/// is omitted (approved) unless given.
Map<String, dynamic> commentJson(
  String id,
  String content, {
  String chapterId = '',
  int? paragraphIndex,
  String? parentId,
  String user = userId,
  List<Map<String, dynamic>> replies = const [],
  String? status,
}) =>
    {
      'id': id,
      'user_id': user,
      'chapter_id': chapterId.isEmpty ? chapterIds[0] : chapterId,
      if (parentId != null) 'parent_id': parentId,
      'content': content,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      'like_count': 0,
      'liked_by_me': false,
      'user': {'id': user, 'username': 'reader1', 'nickname': user == userId ? '讀者一號' : '路人'},
      'replies': replies,
      if (status != null) 'status': status,
      'created_at': DateTime.now().toUtc().toIso8601String(),
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

  /// The `status` new comments get; anything but approved is held back
  /// (kept in [heldComments]): never counted, and listed only to its author
  /// when signed in, like the server.
  String commentStatus = 'approved';
  final List<Map<String, dynamic>> heldComments = [];

  /// Public reviews of [novelId], and the `status` created or edited ones
  /// get; held ones move to [heldReviews] (listed only to their author).
  final List<Map<String, dynamic>> reviews = [];
  String reviewStatus = 'approved';
  final List<Map<String, dynamic>> heldReviews = [];

  static bool _signedIn(FakeRequest r) => r.headers['Authorization'] != null;

  /// The caller's own held items when signed in (others' never).
  static Iterable<Map<String, dynamic>> _ownHeld(FakeRequest r, List<Map<String, dynamic>> held) =>
      _signedIn(r) ? held.where((x) => x['user_id'] == userId) : const [];

  /// Top-level comments of [chapterId] visible to the caller, each with its
  /// visible replies (seeded `replies` plus posted ones with its parent_id).
  List<Map<String, dynamic>> _threads(FakeRequest r, String chapterId) {
    final visible = [...comments, ..._ownHeld(r, heldComments)].where((c) => c['chapter_id'] == chapterId).toList();
    return [
      for (final c in visible.where((c) => c['parent_id'] == null))
        {
          ...c,
          'replies': [
            ...(c['replies'] as List? ?? const []),
            ...visible.where((x) => x['parent_id'] == c['id']),
          ],
        },
    ];
  }
  final List<Map<String, dynamic>> progressUpdates = [];
  final Set<String> bookshelf = {};

  /// Bookshelf novels with update notifications turned off.
  final Set<String> bookshelfMuted = {};

  /// Newest first, like the server.
  final List<Map<String, dynamic>> notifications = [];

  /// Registered devices by record id.
  final Map<String, Map<String, dynamic>> devices = {};

  /// Set to make POST /bookshelf fail with this status.
  int? bookshelfFailure;

  /// Set to make PATCH /bookshelf/{id} fail with this status.
  int? bookshelfPatchFailure;

  /// The signed in user (GET/PATCH /users/me).
  final Map<String, dynamic> me = userJson();

  /// Set to make PATCH /users/me fail with this status.
  int? profilePatchFailure;

  int _deviceSeq = 0;

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
      ..on('GET', '/novels/:id/reviews', (r) => FakeResponse.ok(page([..._ownHeld(r, heldReviews), ...reviews])))
      ..on('DELETE', '/reviews/:id', (r) {
        final before = reviews.length + heldReviews.length;
        reviews.removeWhere((x) => x['id'] == r.params['id']);
        heldReviews.removeWhere((x) => x['id'] == r.params['id']);
        return before == reviews.length + heldReviews.length
            ? FakeResponse.error(404, 40403, 'review not found')
            : FakeResponse.ok(null);
      })
      ..on('POST', '/novels/:id/reviews', (r) {
        if ([...reviews, ...heldReviews].any((x) => x['user_id'] == userId)) {
          return FakeResponse.error(409, 40901, 'already reviewed');
        }
        final review = {
          'id': 'rev1ew00-0000-4000-8000-00000000000${reviews.length + heldReviews.length}',
          'user_id': userId,
          'novel_id': r.params['id'],
          'title': r.json['title'],
          'content': r.json['content'],
          'rating': r.json['rating'],
          'like_count': 0,
          'liked_by_me': false,
          'status': reviewStatus,
          'user': {'id': userId, 'username': 'reader1', 'nickname': '讀者一號'},
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        (reviewStatus == 'approved' ? reviews : heldReviews).add(review);
        return FakeResponse.ok(review, status: 201);
      })
      ..on('PUT', '/reviews/:id', (r) {
        final review = [...reviews, ...heldReviews].where((x) => x['id'] == r.params['id']).firstOrNull;
        if (review == null) return FakeResponse.error(404, 40403, 'review not found');
        for (final key in ['title', 'content', 'rating']) {
          review[key] = r.json[key];
        }
        review['status'] = reviewStatus;
        reviews.remove(review);
        heldReviews.remove(review);
        (reviewStatus == 'approved' ? reviews : heldReviews).add(review);
        return FakeResponse.ok(review);
      })
      ..on('GET', '/chapters/:id/comments', (r) {
        final paragraph = r.query['paragraph_index'];
        return FakeResponse.ok(page(_threads(r, r.params['id']!)
            .where((c) => paragraph == null || c['paragraph_index'] == paragraph)
            .toList()));
      })
      ..on('GET', '/chapters/:id/comments/paragraph-counts', (r) {
        final counts = <int, int>{};
        for (final c in comments) {
          final i = c['paragraph_index'];
          if (c['chapter_id'] == r.params['id'] && c['parent_id'] == null && i is int) {
            counts[i] = (counts[i] ?? 0) + 1;
          }
        }
        final keys = counts.keys.toList()..sort();
        return FakeResponse.ok([
          for (final k in keys) {'paragraph_index': k, 'count': counts[k]},
        ]);
      })
      ..on('GET', '/comments/:id', (r) {
        final id = r.params['id'];
        for (final chapter in chapterIds) {
          for (final c in _threads(r, chapter)) {
            final replies = (c['replies'] as List).cast<Map<String, dynamic>>();
            if (c['id'] == id || replies.any((x) => x['id'] == id)) return FakeResponse.ok(c);
          }
        }
        return FakeResponse.error(404, 40405, 'comment not found');
      })
      ..on('DELETE', '/comments/:id', (r) {
        final id = r.params['id'];
        final before = comments.length + heldComments.length;
        comments.removeWhere((x) => x['id'] == id);
        heldComments.removeWhere((x) => x['id'] == id);
        return before == comments.length + heldComments.length
            ? FakeResponse.error(404, 40405, 'comment not found')
            : FakeResponse.ok(null);
      })
      ..on('POST', '/chapters/:id/comments', (r) {
        final comment = {
          'id': 'c0mment0-0000-4000-8000-00000000000${comments.length + heldComments.length}',
          'user_id': userId,
          'chapter_id': r.params['id'],
          'content': r.json['content'],
          if (r.json['paragraph_index'] != null) 'paragraph_index': r.json['paragraph_index'],
          if (r.json['parent_id'] != null) 'parent_id': r.json['parent_id'],
          'like_count': 0,
          'liked_by_me': false,
          'user': {'id': userId, 'username': 'reader1', 'nickname': '讀者一號'},
          'replies': [],
          'status': commentStatus,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        (commentStatus == 'approved' ? comments : heldComments).add(comment);
        return FakeResponse.ok(comment, status: 201);
      })
      // Unread novel: 200 with data null (older servers answered 404).
      ..on('GET', '/reading-progress/:id', (_) => const FakeResponse(200, {'code': 0, 'message': 'success', 'data': null}))
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
                'is_notified': !bookshelfMuted.contains(id),
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
      ..on('PATCH', '/bookshelf/:id', (r) {
        final failure = bookshelfPatchFailure;
        if (failure != null) return FakeResponse.error(failure, 50001, 'boom');
        final id = r.params['id']!;
        if (!bookshelf.contains(id)) return FakeResponse.error(404, 40401, 'not on bookshelf');
        final notified = r.json['is_notified'];
        if (notified == true) bookshelfMuted.remove(id);
        if (notified == false) bookshelfMuted.add(id);
        return FakeResponse.ok(r.json);
      })
      ..on('GET', '/notifications', (r) {
        final unreadOnly = r.query['unread_only'] == true || r.query['unread_only'] == 'true';
        final size = r.query['page_size'] as int? ?? 20;
        final number = r.query['page'] as int? ?? 1;
        final all = notifications.where((n) => !unreadOnly || n['read_at'] == null).toList();
        final pages = all.isEmpty ? 1 : (all.length + size - 1) ~/ size;
        final items = all.skip((number - 1) * size).take(size).toList();
        return FakeResponse.ok({
          'items': items,
          'pagination': {'page': number, 'page_size': size, 'total': all.length, 'total_pages': pages},
        });
      })
      ..on('GET', '/notifications/unread-count', (_) =>
          FakeResponse.ok({'count': notifications.where((n) => n['read_at'] == null).length}))
      ..on('PUT', '/notifications/read-all', (_) {
        var updated = 0;
        for (final n in notifications) {
          if (n['read_at'] == null) {
            n['read_at'] = DateTime.now().toUtc().toIso8601String();
            updated++;
          }
        }
        return FakeResponse.ok({'updated': updated});
      })
      ..on('PUT', '/notifications/:id/read', (r) {
        final n = notifications.where((n) => n['id'] == r.params['id']).firstOrNull;
        if (n == null) return FakeResponse.error(404, 40410, 'notification not found');
        n['read_at'] ??= DateTime.now().toUtc().toIso8601String();
        return FakeResponse.ok(null);
      })
      ..on('DELETE', '/notifications/:id', (r) {
        final before = notifications.length;
        notifications.removeWhere((n) => n['id'] == r.params['id']);
        return before == notifications.length
            ? FakeResponse.error(404, 40410, 'notification not found')
            : FakeResponse.ok(null);
      })
      ..on('GET', '/users/me/devices', (_) => FakeResponse.ok(devices.values.toList()))
      ..on('POST', '/users/me/devices', (r) {
        final existing = devices.values.where((d) => d['device_id'] == r.json['device_id']).firstOrNull;
        final now = DateTime.now().toUtc().toIso8601String();
        final device = {
          'id': existing?['id'] ?? 'dev1ce00-0000-4000-8000-00000000000${_deviceSeq++}',
          'device_id': r.json['device_id'],
          'device_type': r.json['device_type'],
          if (r.json['device_name'] != null) 'device_name': r.json['device_name'],
          'last_active_at': now,
          'created_at': existing?['created_at'] ?? now,
        };
        devices[device['id'] as String] = device;
        return FakeResponse.ok(device);
      })
      ..on('DELETE', '/users/me/devices/:id', (r) => devices.remove(r.params['id']) == null
          ? FakeResponse.error(404, 40411, 'device not found')
          : FakeResponse.ok(null))
      ..on('POST', '/auth/login', (r) => FakeResponse.ok({
            'access_token': 'login-access',
            'refresh_token': 'login-refresh',
            'expires_in': 86400,
            'user': me,
          }))
      ..on('POST', '/auth/logout', (_) => FakeResponse.ok(null))
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
      ..on('GET', '/users/me', (_) => FakeResponse.ok(me))
      ..on('PATCH', '/users/me', (r) {
        final failure = profilePatchFailure;
        if (failure != null) return FakeResponse.error(failure, 50001, 'boom');
        for (final key in ['nickname', 'bio', 'avatar_url', 'language_pref']) {
          if (r.json.containsKey(key)) me[key] = r.json[key];
        }
        return FakeResponse.ok(me);
      })
      ..on('GET', '/users/me/reading-settings', (_) => FakeResponse.ok({
            'font_size': 18,
            'line_height': 1.8,
            'theme': 'white',
            'reading_mode': 'scroll',
            'page_animation': 'slide',
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
