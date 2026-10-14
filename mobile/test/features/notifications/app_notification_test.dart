import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/l10n/l10n.dart';
import 'package:palimpsest/features/notifications/domain/entities/app_notification.dart';
import 'package:palimpsest/features/notifications/presentation/notification_text.dart';

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
      const n = AppNotification(id: 'n', type: 'chapter_update', title: 't', chapterId: 'c', params: {'novel': 'v'});
      final at = DateTime.utc(2026, 1, 1);
      final read = n.markedRead(at);
      expect(read.readAt, at);
      expect(read.chapterId, 'c');
      expect(read.params, {'novel': 'v'});
      expect(identical(read.markedRead(), read), isTrue);
    });

    test('parses params, keeping strings (and numbers as text) only', () {
      final n = AppNotification.fromJson({
        'id': 'n3',
        'type': 'chapter_update',
        'title': '《霧港燈塔》有新章節',
        'params': {'novel': '霧港燈塔', 'chapter': '十點鐘', 'chapter_number': 2, 'empty': '', 'bad': null, 'list': []},
      });
      expect(n.params, {'novel': '霧港燈塔', 'chapter': '十點鐘', 'chapter_number': '2'});
      expect(AppNotification.fromJson({'id': 'n4', 'title': 'x'}).params, isEmpty);
      expect(AppNotification.fromJson({'id': 'n5', 'title': 'x', 'params': 'nope'}).params, isEmpty);
    });
  });

  group('localized notification text', () {
    final zhTW = lookupAppLocalizations(const Locale('zh', 'TW'));
    final zhCN = lookupAppLocalizations(const Locale('zh', 'CN'));
    final en = lookupAppLocalizations(const Locale('en'));

    const chapterUpdate = AppNotification(
      id: 'n',
      type: NotificationTypes.chapterUpdate,
      title: '《霧港燈塔》有新章節',
      body: '更新至：十點鐘',
      params: {'novel': '霧港燈塔', 'chapter': '十點鐘', 'chapter_number': '2'},
    );

    test('chapter update is written in each UI language with the chapter label', () {
      expect(chapterUpdate.localizedTitle(zhTW), '《霧港燈塔》有新章節');
      expect(chapterUpdate.localizedBody(zhTW), '更新至：第2章 十點鐘');
      expect(chapterUpdate.localizedTitle(zhCN), '《霧港燈塔》有新章节');
      expect(chapterUpdate.localizedBody(zhCN), '更新至：第2章 十點鐘');
      expect(chapterUpdate.localizedTitle(en), 'New chapters in 霧港燈塔');
      expect(chapterUpdate.localizedBody(en), 'Updated to Chapter 2: 十點鐘');
    });

    test('a chapter title with its own number is not numbered twice', () {
      const n = AppNotification(
        id: 'n',
        type: NotificationTypes.chapterUpdate,
        title: 't',
        params: {'novel': '霧港燈塔', 'chapter': '第二章 十點鐘', 'chapter_number': '2'},
      );
      expect(n.localizedBody(zhTW), '更新至：第二章 十點鐘');
      expect(n.localizedBody(en), 'Updated to 第二章 十點鐘');
    });

    test('comment reply names the replier; the body is the excerpt as sent', () {
      const n = AppNotification(
        id: 'n',
        type: NotificationTypes.commentReply,
        title: '路人 回覆了你的留言',
        body: '我也這麼覺得',
        params: {'actor': '路人'},
      );
      expect(n.localizedTitle(zhTW), '路人 回覆了你的留言');
      expect(n.localizedTitle(zhCN), '路人 回复了你的留言');
      expect(n.localizedTitle(en), '路人 replied to your comment');
      expect(n.localizedBody(en), '我也這麼覺得');
    });

    test('without params (old notifications, system) the server text is shown', () {
      const old = AppNotification(id: 'n', type: NotificationTypes.chapterUpdate, title: '《霧港燈塔》有新章節', body: '更新至：十點鐘');
      expect(old.localizedTitle(en), '《霧港燈塔》有新章節');
      expect(old.localizedBody(en), '更新至：十點鐘');

      const oldReply = AppNotification(id: 'n', type: NotificationTypes.commentReply, title: '路人 回覆了你的留言');
      expect(oldReply.localizedTitle(en), '路人 回覆了你的留言');
      expect(oldReply.localizedBody(en), isNull);

      const system = AppNotification(id: 'n', type: NotificationTypes.system, title: '系統維護公告', body: '週六維護');
      expect(system.localizedTitle(en), '系統維護公告');
      expect(system.localizedBody(en), '週六維護');
    });

    test('missing keys fall back piece by piece', () {
      const noNumber = AppNotification(
        id: 'n',
        type: NotificationTypes.chapterUpdate,
        title: '《霧港燈塔》有新章節',
        body: '更新至：十點鐘',
        params: {'chapter': '十點鐘'},
      );
      expect(noNumber.localizedTitle(en), '《霧港燈塔》有新章節');
      expect(noNumber.localizedBody(en), 'Updated to 十點鐘');

      const noChapter = AppNotification(
        id: 'n',
        type: NotificationTypes.chapterUpdate,
        title: 't',
        body: '更新至：十點鐘',
        params: {'novel': '霧港燈塔'},
      );
      expect(noChapter.localizedTitle(en), 'New chapters in 霧港燈塔');
      expect(noChapter.localizedBody(en), '更新至：十點鐘');

      const wrongType = AppNotification(id: 'n', type: NotificationTypes.system, title: '公告', params: {'novel': 'x'});
      expect(wrongType.localizedTitle(en), '公告');
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
