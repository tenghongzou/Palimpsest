import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/devices/data/device_registration.dart';
import 'package:palimpsest/features/devices/domain/entities/user_device.dart';
import 'package:palimpsest/features/notifications/presentation/providers/notification_providers.dart';
import 'package:palimpsest/features/reader/domain/entities/chapter.dart';
import 'package:palimpsest/features/reader/presentation/providers/reader_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

const n1 = '11111111-0000-4000-8000-000000000001';
const n2 = '11111111-0000-4000-8000-000000000002';
const n3 = '11111111-0000-4000-8000-000000000003';
const threadId = '22222222-0000-4000-8000-000000000001';
const replyId = '22222222-0000-4000-8000-000000000002';

Finder badgeWith(String label) => find.descendant(of: find.byType(Badge), matching: find.text(label));

void main() {
  late TestEnv env;

  Future<void> start(WidgetTester tester, {bool signedIn = true}) async {
    env = await TestEnv.create(signedIn: signedIn);
    await env.pumpApp(tester);
  }

  tearDown(() => env.dispose());

  void seedNotifications() {
    env.backend.notifications.addAll([
      notificationJson(n1,
          type: 'chapter_update', title: '《霧港燈塔》有新章節', body: '更新至：第二章 十點鐘', chapterId: chapterIds[1]),
      notificationJson(n2,
          type: 'comment_reply',
          title: '路人 回覆了你的留言',
          body: '我也這麼覺得',
          chapterId: chapterIds[0],
          commentId: threadId),
      notificationJson(n3, title: '系統維護公告', body: '本週六凌晨兩點進行系統維護。', read: true),
    ]);
  }

  group('unread badge', () {
    testWidgets('shows the unread count on home and refreshes periodically and on resume', (tester) async {
      env = await TestEnv.create();
      seedNotifications();
      await env.pumpApp(tester);
      await tester.pumpAndSettle();
      expect(badgeWith('2'), findsOneWidget);

      // Polled every minute while in the foreground.
      env.backend.notifications.add(notificationJson('11111111-0000-4000-8000-000000000004', title: '新公告'));
      await tester.pump(UnreadCountNotifier.pollInterval + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(badgeWith('3'), findsOneWidget);

      // No polling in the background; refreshed on resume.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      env.backend.notifications.removeLast();
      final before = env.backend.api.calls('GET', '/notifications/unread-count').length;
      await tester.pump(UnreadCountNotifier.pollInterval * 2);
      expect(env.backend.api.calls('GET', '/notifications/unread-count').length, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(badgeWith('2'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('no bell while signed out', (tester) async {
      await start(tester, signedIn: false);
      expect(find.byTooltip('通知'), findsNothing);
      expect(env.backend.api.calls('GET', '/notifications'), isEmpty);
      await env.finish(tester);
    });
  });

  group('notifications page', () {
    testWidgets('lists with unread styling; system opens its body and marks it read', (tester) async {
      env = await TestEnv.create();
      seedNotifications();
      env.backend.notifications.insert(0, notificationJson('11111111-0000-4000-8000-000000000005', title: '新功能上線', body: '現在可以在段落留言了。'));
      await env.pumpApp(tester);
      await tester.tap(find.byType(Badge));
      await tester.pumpAndSettle();

      expect(find.text('通知'), findsOneWidget);
      expect(find.text('《霧港燈塔》有新章節'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot-$n1')), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot-$n3')), findsNothing);

      await tester.tap(find.text('新功能上線'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('現在可以在段落留言了。'), findsWidgets);
      await tester.tap(find.text('關閉'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('unread-dot-11111111-0000-4000-8000-000000000005')), findsNothing);
      expect(env.backend.notifications.first['read_at'], isNotNull);
      expect(env.container(tester).read(unreadCountProvider), 2);
      await env.finish(tester);
    });

    void seedWithParams() {
      env.backend.notifications.addAll([
        notificationJson(n1,
            type: 'chapter_update',
            title: '《霧港燈塔》有新章節',
            body: '更新至：十點鐘',
            chapterId: chapterIds[1],
            params: {'novel': '霧港燈塔', 'chapter': '十點鐘', 'chapter_number': '2'}),
        notificationJson(n2,
            type: 'comment_reply',
            title: '路人 回覆了你的留言',
            body: '我也這麼覺得',
            chapterId: chapterIds[0],
            commentId: threadId,
            params: {'actor': '路人'}),
        notificationJson(n3, title: '系統維護公告', body: '本週六凌晨兩點進行系統維護。', read: true),
      ]);
    }

    testWidgets('titles and bodies follow the UI language (English)', (tester) async {
      env = await TestEnv.create(uiLanguage: 'en', accountLanguage: 'en');
      seedWithParams();
      await env.pumpApp(tester);
      await env.push(tester, '/notifications');
      expect(find.text('New chapters in 霧港燈塔'), findsOneWidget);
      expect(find.text('Updated to Chapter 2: 十點鐘'), findsOneWidget);
      expect(find.text('路人 replied to your comment'), findsOneWidget);
      expect(find.text('我也這麼覺得'), findsOneWidget);
      // System notifications have no params: shown as sent.
      expect(find.text('系統維護公告'), findsOneWidget);
      expect(find.text('《霧港燈塔》有新章節'), findsNothing);
      await env.finish(tester);
    });

    testWidgets('titles and bodies follow the UI language (zh-CN and zh-TW)', (tester) async {
      env = await TestEnv.create(uiLanguage: 'zh-CN', accountLanguage: 'zh-CN');
      seedWithParams();
      await env.pumpApp(tester);
      await env.push(tester, '/notifications');
      expect(find.text('《霧港燈塔》有新章节'), findsOneWidget);
      expect(find.text('更新至：第2章 十點鐘'), findsOneWidget);
      expect(find.text('路人 回复了你的留言'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('zh-TW renders from params too', (tester) async {
      env = await TestEnv.create();
      seedWithParams();
      await env.pumpApp(tester);
      await env.push(tester, '/notifications');
      expect(find.text('《霧港燈塔》有新章節'), findsOneWidget);
      expect(find.text('更新至：第2章 十點鐘'), findsOneWidget);
      expect(find.text('路人 回覆了你的留言'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('chapter update opens the reader at that chapter', (tester) async {
      env = await TestEnv.create();
      seedNotifications();
      await env.pumpApp(tester);
      await env.push(tester, '/notifications');
      await tester.tap(find.text('《霧港燈塔》有新章節'));
      await tester.pumpAndSettle();
      expect(find.text(chapterTitles[1]), findsOneWidget);
      expect(env.backend.api.calls('PUT', '/notifications/$n1/read'), hasLength(1));
      await env.finish(tester);
    });

    Future<void> openReplyNotification(WidgetTester tester) async {
      await env.pumpApp(tester);
      await env.push(tester, '/notifications');
      await tester.tap(find.text('路人 回覆了你的留言'));
      await tester.pumpAndSettle();
    }

    Finder inPinnedThread(String text) =>
        find.descendant(of: find.byKey(const ValueKey('focused-thread')), matching: find.text(text));

    testWidgets('comment reply on a paragraph opens that paragraph with the thread pinned', (tester) async {
      env = await TestEnv.create();
      seedNotifications();
      env.backend.comments.add(commentJson(threadId, '燈塔裡到底是誰？', paragraphIndex: 2, replies: [
        commentJson(replyId, '我也這麼覺得', parentId: threadId, user: '99999999-0000-4000-8000-000000000000'),
      ]));
      await openReplyNotification(tester);

      expect(find.text(chapterTitles[0]), findsOneWidget);
      expect(find.text('第 3 段的留言'), findsOneWidget);
      expect(find.text('第1章的第三段。'), findsWidgets); // the quoted paragraph
      expect(inPinnedThread('燈塔裡到底是誰？'), findsOneWidget);
      expect(inPinnedThread('我也這麼覺得'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/comments/$threadId'), hasLength(1));
      // The thread is fetched directly; the list is not paged through.
      final lists = env.backend.api.requests
          .where((r) => r.method == 'GET' && r.path == '/chapters/${chapterIds[0]}/comments')
          .toList();
      expect(lists.map((r) => r.query['page']), everyElement(1));
      expect(lists.last.query['paragraph_index'], 2);

      // Replying in the pinned thread refreshes it.
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('focused-thread')), matching: find.text('回覆')).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '真的');
      await tester.tap(find.byTooltip('送出留言'));
      await tester.pumpAndSettle();
      expect(env.backend.api.calls('POST', '/chapters/${chapterIds[0]}/comments').last.json['parent_id'], threadId);
      expect(env.backend.api.calls('GET', '/comments/$threadId'), hasLength(2));
      await env.finish(tester);
    });

    testWidgets('comment reply on the chapter opens the chapter comments with the thread pinned', (tester) async {
      env = await TestEnv.create();
      seedNotifications();
      env.backend.comments.add(commentJson(threadId, '這章節奏很好', replies: [
        commentJson(replyId, '我也這麼覺得', parentId: threadId, user: '99999999-0000-4000-8000-000000000000'),
      ]));
      await openReplyNotification(tester);

      expect(find.text('本章留言'), findsWidgets);
      expect(find.textContaining('段的留言'), findsNothing);
      expect(inPinnedThread('這章節奏很好'), findsOneWidget);
      expect(inPinnedThread('我也這麼覺得'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/chapters/${chapterIds[0]}/comments').last.query.containsKey('paragraph_index'),
          isFalse);
      await env.finish(tester);
    });

    testWidgets('comment reply to a deleted thread says it is gone', (tester) async {
      env = await TestEnv.create();
      seedNotifications();
      await openReplyNotification(tester);

      expect(find.text('本章留言'), findsWidgets);
      expect(find.byKey(const ValueKey('focused-thread')), findsNothing);
      expect(find.text('找不到這則留言，可能已被刪除'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('mark all read and swipe to delete', (tester) async {
      env = await TestEnv.create();
      seedNotifications();
      await env.pumpApp(tester);
      await env.push(tester, '/notifications');

      await tester.tap(find.text('全部已讀'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('unread-dot-$n1')), findsNothing);
      expect(env.backend.notifications.every((n) => n['read_at'] != null), isTrue);
      expect(env.container(tester).read(unreadCountProvider), 0);

      await tester.drag(find.text('系統維護公告'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      // Let the DELETE request go out (no frames are scheduled any more).
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('系統維護公告'), findsNothing);
      expect(env.backend.notifications.map((n) => n['id']), isNot(contains(n3)));
      await env.finish(tester);
    });

    testWidgets('paginates', (tester) async {
      env = await TestEnv.create();
      for (var i = 0; i < 25; i++) {
        env.backend.notifications.add(notificationJson('44444444-0000-4000-8000-0000000000${i.toString().padLeft(2, '0')}',
            title: '公告 $i', read: true));
      }
      await env.pumpApp(tester);
      await env.push(tester, '/notifications');
      await tester.scrollUntilVisible(find.text('公告 24'), 300);
      await tester.pumpAndSettle();
      expect(find.text('公告 24'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/notifications').map((r) => r.query['page']), containsAll([1, 2]));
      await env.finish(tester);
    });

    testWidgets('offline shows a friendly empty state', (tester) async {
      await start(tester);
      env.backend.api.offline = true;
      await env.push(tester, '/notifications');
      expect(find.text('目前離線，連線後即可查看通知'), findsOneWidget);
      env.backend.api.offline = false;
      await env.finish(tester);
    });
  });

  group('paragraph comments', () {
    testWidgets('bubbles show counts; tap and long-press open the paragraph thread; posting refreshes counts',
        (tester) async {
      env = await TestEnv.create();
      env.backend.comments.add(commentJson('55555555-0000-4000-8000-000000000001', '第二段好有畫面', paragraphIndex: 1));
      await env.pumpApp(tester);
      await env.push(tester, '/read/${chapterIds[0]}');

      final bubble = find.byKey(const ValueKey('paragraph-comments-1'));
      expect(bubble, findsOneWidget);
      expect(find.descendant(of: bubble, matching: find.text('1')), findsOneWidget);
      expect(find.byKey(const ValueKey('paragraph-comments-0')), findsNothing);

      await tester.tap(bubble);
      await tester.pumpAndSettle();
      expect(find.text('第 2 段的留言'), findsOneWidget);
      expect(find.text('第二段好有畫面'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/chapters/${chapterIds[0]}/comments').last.query['paragraph_index'], 1);
      await tester.tap(find.byTooltip('關閉'));
      await tester.pumpAndSettle();
      // Opening the sheet did not toggle the toolbar.
      expect(find.byTooltip('目錄'), findsNothing);

      await tester.longPress(find.textContaining('第1章的第一段'));
      await tester.pumpAndSettle();
      expect(find.text('第 1 段的留言'), findsOneWidget);
      expect(find.text('這一段還沒有留言，寫下第一則吧'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '開頭就很吸引人');
      await tester.tap(find.byTooltip('送出留言'));
      await tester.pumpAndSettle();
      expect(find.text('開頭就很吸引人'), findsOneWidget);
      final posted = env.backend.api.calls('POST', '/chapters/${chapterIds[0]}/comments').last.json;
      expect(posted['paragraph_index'], 0);

      await tester.tap(find.byTooltip('關閉'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paragraph-comments-0')), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('page mode: side taps still turn pages with bubbles shown', (tester) async {
      env = await TestEnv.create();
      env.backend.comments.add(commentJson('55555555-0000-4000-8000-000000000001', '好', paragraphIndex: 0));
      await env.pumpApp(tester);
      env.container(tester).read(readerSettingsProvider.notifier)
        ..updateReadingMode('page')
        ..updateAutoChapter(true);
      await env.push(tester, '/read/${chapterIds[0]}');
      expect(find.byKey(const ValueKey('paragraph-comments-0')), findsOneWidget);

      final size = tester.getSize(find.byType(Scaffold).last);
      await tester.tapAt(Offset(size.width * 0.5, size.height * 0.8));
      await tester.pumpAndSettle();
      expect(find.byTooltip('目錄'), findsOneWidget);
      await tester.tapAt(Offset(size.width * 0.5, size.height * 0.5));
      await tester.pumpAndSettle();

      await tester.tapAt(Offset(size.width * 0.9, size.height * 0.8));
      await pumpUntilFound(tester, find.text(chapterTitles[1]));
      expect(find.text(chapterTitles[1]), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('posting requires signing in', (tester) async {
      await start(tester, signedIn: false);
      await env.push(tester, '/read/${chapterIds[0]}');
      await tester.longPress(find.textContaining('第1章的第二段'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 段的留言'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '想留言');
      await tester.tap(find.byTooltip('送出留言'));
      await tester.pumpAndSettle();
      expect(find.text('帳號 / 電子郵件'), findsOneWidget);
      expect(env.backend.api.calls('POST', '/chapters'), isEmpty);
      await env.finish(tester);
    });

    testWidgets('offline cached chapter: no bubbles and long-press does nothing', (tester) async {
      await start(tester);
      await env.store.saveChapter(Chapter(
        id: chapterIds[0],
        novelId: novelId,
        title: chapterTitles[0],
        content: chapterContent(0),
        chapterNumber: 1,
      ));
      env.backend.comments.add(commentJson('55555555-0000-4000-8000-000000000001', '好', paragraphIndex: 0));
      env.backend.api.offline = true;
      await env.push(tester, '/read/${chapterIds[0]}');
      expect(find.text('離線模式：顯示的是本機快取的章節'), findsOneWidget);
      expect(find.byKey(const ValueKey('paragraph-comments-0')), findsNothing);
      await tester.longPress(find.textContaining('第1章的第一段'));
      await tester.pumpAndSettle();
      expect(find.text('第 1 段的留言'), findsNothing);
      await env.finish(tester);
    });
  });

  group('bookshelf update notifications', () {
    testWidgets('toggle is optimistic and rolls back on failure', (tester) async {
      env = await TestEnv.create();
      env.backend.bookshelf.add(novelId);
      await env.pumpApp(tester);
      await env.push(tester, '/bookshelf');
      expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);

      await tester.longPress(find.text('霧港燈塔'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
      await tester.tap(find.text('更新通知'));
      await tester.pumpAndSettle();
      expect(find.text('已關閉更新通知'), findsOneWidget);
      expect(env.backend.bookshelfMuted, {novelId});
      expect(env.backend.api.calls('PATCH', '/bookshelf/$novelId').last.json, {'is_notified': false});
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

      env.backend.bookshelfPatchFailure = 500;
      await tester.longPress(find.text('霧港燈塔'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更新通知'));
      await tester.pumpAndSettle();
      expect(find.text('伺服器錯誤，請稍後再試'), findsOneWidget);
      // Rolled back: still off.
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
      expect(env.backend.bookshelfMuted, {novelId});
      await env.finish(tester);
    });
  });

  group('devices', () {
    testWidgets('registers once per launch when signed in at start', (tester) async {
      await start(tester);
      await tester.pumpAndSettle();
      expect(env.backend.devices, hasLength(1));
      final device = env.backend.devices.values.single;
      expect(deviceTypes, contains(device['device_type']));
      final prefs = await SharedPreferences.getInstance();
      expect(device['device_id'], prefs.getString(DeviceIdentity.prefsKey));
      expect(env.backend.api.calls('POST', '/users/me/devices').single.json.containsKey('push_token'), isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(env.backend.api.calls('POST', '/users/me/devices'), hasLength(1));
      await env.finish(tester);
    });

    testWidgets('registers after login and is removed on logout before the session ends', (tester) async {
      env = await TestEnv.create(signedIn: false);
      env.backend.notifications.add(notificationJson(n1, title: '歡迎'));
      await env.pumpApp(tester);
      expect(env.backend.devices, isEmpty);

      await env.push(tester, '/login');
      await tester.enterText(find.byType(TextFormField).at(0), 'reader1');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, '登入'));
      await tester.pumpAndSettle();
      expect(env.backend.devices, hasLength(1));
      expect(badgeWith('1'), findsOneWidget);

      await env.push(tester, '/profile');
      await tester.scrollUntilVisible(find.text('登出'), 200, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('登出'));
      await tester.pumpAndSettle();
      expect(env.backend.devices, isEmpty);
      final paths = env.backend.api.requests.map((r) => '${r.method} ${r.path}').toList();
      expect(paths.indexWhere((p) => p.startsWith('DELETE /users/me/devices/')),
          lessThan(paths.indexOf('POST /auth/logout')));
      expect(env.backend.api.requests.firstWhere((r) => r.method == 'DELETE').headers['Authorization'],
          'Bearer login-access');
      expect(find.byType(Badge), findsNothing);
      await env.finish(tester);
    });

    testWidgets('devices page marks this device and removes another', (tester) async {
      await start(tester);
      await tester.pumpAndSettle();
      env.backend.devices['dev1ce00-0000-4000-8000-0000000000ff'] = {
        'id': 'dev1ce00-0000-4000-8000-0000000000ff',
        'device_id': 'other-install',
        'device_type': 'ios',
        'device_name': '舊 iPhone',
        'last_active_at': '2026-10-01T08:00:00Z',
        'created_at': '2026-09-01T08:00:00Z',
      };
      await env.push(tester, '/settings');
      await tester.tap(find.text('登入裝置'));
      await tester.pumpAndSettle();

      expect(find.text('此裝置'), findsOneWidget);
      expect(find.text('舊 iPhone'), findsOneWidget);
      // Only the other device can be removed here.
      expect(find.byTooltip('移除裝置'), findsOneWidget);
      await tester.tap(find.byTooltip('移除裝置'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '移除'));
      await tester.pumpAndSettle();
      expect(find.text('舊 iPhone'), findsNothing);
      expect(env.backend.devices.keys, isNot(contains('dev1ce00-0000-4000-8000-0000000000ff')));
      expect(env.backend.devices, hasLength(1));
      await env.finish(tester);
    });
  });
}
