import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/notifications/domain/entities/app_notification.dart';

void main() {
  group('AppNotification.fromJson', () {
    test('parses a comment reply with its actor', () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'type': 'comment_reply',
        'title': '路人 回覆了你的留言',
        'body': '我也這麼覺得',
        'novel_id': 'novel',
        'chapter_id': 'chapter',
        'comment_id': 'thread',
        'read_at': null,
        'created_at': '2026-10-14T08:00:00Z',
        'actor': {'id': 'u2', 'username': 'passerby', 'nickname': '路人', 'avatar_url': 'https://x/a.png'},
      });
      expect(n.type, NotificationTypes.commentReply);
      expect(n.body, '我也這麼覺得');
      expect(n.isRead, isFalse);
      expect(n.createdAt, DateTime.utc(2026, 10, 14, 8));
      expect(n.actor?.displayName, '路人');
      expect(n.actor?.avatarUrl, 'https://x/a.png');
    });

    test('omitted and empty optional fields are null; read_at marks it read', () {
      final n = AppNotification.fromJson({
        'id': 'n2',
        'type': 'system',
        'title': '公告',
        'body': '',
        'read_at': '2026-10-14T09:00:00Z',
        'created_at': '2026-10-14T08:00:00Z',
      });
      expect(n.body, isNull);
      expect(n.novelId, isNull);
      expect(n.chapterId, isNull);
      expect(n.actor, isNull);
      expect(n.isRead, isTrue);
    });

    test('markedRead keeps the fields and only sets read_at once', () {
      const n = AppNotification(id: 'n', type: 'chapter_update', title: 't', chapterId: 'c');
      final at = DateTime.utc(2026, 1, 1);
      final read = n.markedRead(at);
      expect(read.readAt, at);
      expect(read.chapterId, 'c');
      expect(identical(read.markedRead(), read), isTrue);
    });
  });

  group('AppNotification.location', () {
    test('chapter update opens the reader, or the novel without a chapter', () {
      expect(const AppNotification(id: 'n', type: 'chapter_update', title: '', chapterId: 'c').location, '/read/c');
      expect(const AppNotification(id: 'n', type: 'chapter_update', title: '', novelId: 'v').location, '/novel/v');
    });

    test('comment reply opens the chapter focused on the thread', () {
      expect(
        const AppNotification(id: 'n', type: 'comment_reply', title: '', chapterId: 'c', commentId: 't').location,
        '/read/c?comment=t',
      );
      expect(const AppNotification(id: 'n', type: 'comment_reply', title: '', chapterId: 'c').location, '/read/c');
    });

    test('system and unknown types have no link', () {
      expect(const AppNotification(id: 'n', type: 'system', title: '', chapterId: 'c').location, isNull);
      expect(const AppNotification(id: 'n', type: 'something_new', title: '').location, isNull);
    });
  });
}
