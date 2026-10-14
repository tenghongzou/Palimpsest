import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/reader/domain/entities/chapter.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

Chapter seedChapter(int i) => Chapter(
      id: chapterIds[i],
      novelId: novelId,
      title: chapterTitles[i],
      content: chapterContent(i),
      chapterNumber: i + 1,
    );

void main() {
  late TestEnv env;

  Future<void> start(WidgetTester tester, {bool signedIn = true}) async {
    env = await TestEnv.create(signedIn: signedIn);
    await env.pumpApp(tester);
  }

  tearDown(() => env.dispose());

  group('reader', () {
    testWidgets('offline: cached chapter, neighbours and table of contents', (tester) async {
      await start(tester);
      for (final i in [0, 1, 2]) {
        await env.store.saveChapter(seedChapter(i));
      }
      env.backend.api.offline = true;

      await env.push(tester, '/read/${chapterIds[1]}');
      expect(find.text('離線模式：顯示的是本機快取的章節'), findsOneWidget);
      expect(find.text(chapterTitles[1]), findsOneWidget);

      await showReaderToolbar(tester);
      await tester.tap(find.byTooltip('目錄'));
      await tester.pumpAndSettle();
      expect(find.text('（離線：僅顯示已存章節）'), findsOneWidget);
      await tester.tap(find.text(chapterTitles[2]).last);
      await tester.pumpAndSettle();
      expect(find.text(chapterTitles[2]), findsOneWidget);
      expect(find.text('已是最新章'), findsOneWidget);

      await showReaderToolbar(tester);
      await tester.tap(find.widgetWithText(TextButton, '上一章').last);
      await tester.pumpAndSettle();
      expect(find.text(chapterTitles[1]), findsWidgets);
      await env.finish(tester);
    });

    testWidgets('translation: friendly message without an English provider, then zh-CN', (tester) async {
      await start(tester);
      await env.push(tester, '/read/${chapterIds[1]}');
      await showReaderToolbar(tester);
      await tester.tap(find.byTooltip('翻譯'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('英文翻譯服務目前尚未開放，請稍後再試'), findsOneWidget);

      await tester.tap(find.text('简体中文'));
      await tester.pumpAndSettle();
      expect(find.text('简体的第一段。\n\n简体的第二段。'), findsOneWidget);
      await tester.tap(find.text('在閱讀器中顯示譯文'));
      await tester.pumpAndSettle();
      expect(find.text('正在顯示譯文（简体中文）'), findsOneWidget);
      expect(find.textContaining('简体的第一段'), findsOneWidget);

      await tester.tap(find.text('顯示原文'));
      await tester.pumpAndSettle();
      expect(find.textContaining('第2章的第一段'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('chapter comments: post and list', (tester) async {
      await start(tester);
      await env.push(tester, '/read/${chapterIds[0]}');
      await showReaderToolbar(tester);
      await tester.tap(find.byTooltip('留言'));
      await tester.pumpAndSettle();
      expect(find.text('本章留言'), findsWidgets);
      expect(find.text('還沒有留言，來搶頭香吧'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '燈塔好神秘');
      await tester.tap(find.byTooltip('送出留言'));
      await tester.pumpAndSettle();
      expect(find.text('燈塔好神秘'), findsOneWidget);
      expect(env.backend.comments.single['content'], '燈塔好神秘');
      await env.finish(tester);
    });

    testWidgets('bookmarks list jumps back into the reader', (tester) async {
      await start(tester);
      await env.push(tester, '/read/${chapterIds[0]}');
      await showReaderToolbar(tester);
      await tester.tap(find.byTooltip('加入書籤'));
      await tester.pumpAndSettle();

      await env.push(tester, '/bookmarks');
      expect(find.text('我的書籤'), findsOneWidget);
      expect(find.text(chapterTitles[0]), findsOneWidget);
      await tester.tap(find.text(chapterTitles[0]));
      await tester.pumpAndSettle();
      expect(find.textContaining('第1章的第一段'), findsOneWidget);
      await env.finish(tester);
    });
  });

  group('novel detail', () {
    testWidgets('add to bookshelf reports failures and success only after the request', (tester) async {
      await start(tester);
      env.backend.bookshelfFailure = 500;
      await env.push(tester, '/novel/$novelId');

      await tester.tap(find.text('加入書架'));
      await tester.pumpAndSettle();
      expect(find.textContaining('加入書架失敗'), findsOneWidget);
      expect(find.text('已加入書架'), findsNothing);

      env.backend.bookshelfFailure = null;
      await tester.tap(find.text('加入書架'));
      await tester.pumpAndSettle();
      expect(find.text('已加入書架'), findsOneWidget);
      expect(find.text('已在書架'), findsOneWidget);
      expect(env.backend.bookshelf, {novelId});
      await env.finish(tester);
    });

    testWidgets('continue reading resumes from saved progress', (tester) async {
      await start(tester);
      await env.store.saveProgress(
        novelId: novelId,
        chapterId: chapterIds[1],
        scrollOffset: 0.5,
        paragraphIndex: 1,
        readAt: DateTime.now(),
      );
      await env.push(tester, '/novel/$novelId');
      expect(find.text('繼續閱讀'), findsOneWidget);
      await tester.tap(find.text('繼續閱讀'));
      await tester.pumpAndSettle();
      expect(find.text(chapterTitles[1]), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('downloads every chapter and lists the novel under downloads', (tester) async {
      await start(tester);
      await env.push(tester, '/novel/$novelId');
      await tester.tap(find.text('下載全部章節（離線閱讀）'));
      await pumpUntilFound(tester, find.text('已下載全部章節'));
      expect(find.text('已下載全部章節'), findsOneWidget);

      await env.push(tester, '/downloads');
      expect(find.text('霧港燈塔'), findsOneWidget);
      expect(find.textContaining('3/3 章'), findsOneWidget);

      await tester.tap(find.byTooltip('刪除下載'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      expect(await env.store.downloadedNovels(), isEmpty);
      await env.finish(tester);
    });
  });

  group('navigation', () {
    testWidgets('home "更多" opens rankings; categories open a filtered list', (tester) async {
      await start(tester);
      await tester.tap(find.text('更多').first);
      await tester.pumpAndSettle();
      expect(find.text('排行榜'), findsOneWidget);
      expect(find.text('人氣榜'), findsOneWidget);
      expect(find.text('霧港燈塔'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/rankings/views'), isNotEmpty);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('分類'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('玄幻'));
      await tester.pumpAndSettle();
      expect(find.text('玄幻'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/novels').last.query['category'], 'xuanhuan');
      expect(env.backend.api.calls('GET', '/novels').last.query['sort_by'], 'latest');
      await env.finish(tester);
    });

    testWidgets('profile shows stats and opens history and settings', (tester) async {
      await start(tester);
      await env.push(tester, '/profile');
      expect(find.text('讀者一號'), findsOneWidget);
      expect(find.text('1 小時'), findsOneWidget);
      // The chart's title does not repeat the period the dropdown shows.
      expect(find.text('閱讀時間'), findsNWidgets(2));
      expect(find.textContaining('閱讀時間 ·'), findsNothing);
      expect(find.text('近 7 天'), findsOneWidget);

      await tester.ensureVisible(find.text('閱讀記錄'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('閱讀記錄'));
      await tester.pumpAndSettle();
      expect(find.text('霧港燈塔'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('設定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();
      expect(find.text('修改密碼'), findsOneWidget);
      await tester.tap(find.text('閱讀設定'));
      await tester.pumpAndSettle();
      expect(find.text('字體大小'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('login: field errors clear as the user types after a failed submit', (tester) async {
      await start(tester, signedIn: false);
      await env.push(tester, '/login');
      final submit = find.widgetWithText(FilledButton, '登入');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('請輸入帳號或電子郵件'), findsOneWidget);
      expect(find.text('請輸入密碼'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), 'secret-123');
      await tester.pumpAndSettle();
      expect(find.text('請輸入密碼'), findsNothing);
      expect(find.text('請輸入帳號或電子郵件'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'reader1');
      await tester.pumpAndSettle();
      expect(find.text('請輸入帳號或電子郵件'), findsNothing);

      // Clearing a field again brings its error back.
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.pumpAndSettle();
      expect(find.text('請輸入密碼'), findsOneWidget);
      expect(env.backend.api.calls('POST', '/auth/login'), isEmpty);
      await env.finish(tester);
    });

    testWidgets('login: no errors while typing before the first submit', (tester) async {
      await start(tester, signedIn: false);
      await env.push(tester, '/login');
      await tester.enterText(find.byType(TextFormField).at(1), 'x');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.pumpAndSettle();
      expect(find.text('請輸入密碼'), findsNothing);
      await env.finish(tester);
    });

    testWidgets('register: field errors update as the user types after a failed submit', (tester) async {
      await start(tester, signedIn: false);
      await env.push(tester, '/register');
      final submit = find.widgetWithText(FilledButton, '註冊');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('請輸入帳號'), findsOneWidget);
      expect(find.text('請輸入暱稱'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), '讀者');
      await tester.pumpAndSettle();
      expect(find.text('請輸入暱稱'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(0), 'ab');
      await tester.pumpAndSettle();
      expect(find.text('請輸入帳號'), findsNothing);
      expect(find.text('帳號需 4-20 個字元'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'abcd');
      await tester.pumpAndSettle();
      expect(find.text('帳號需 4-20 個字元'), findsNothing);
      await env.finish(tester);
    });

    testWidgets('login links to forgot password', (tester) async {
      await start(tester, signedIn: false);
      await env.push(tester, '/login');
      await tester.tap(find.text('忘記密碼？'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'reader1@example.com');
      await tester.tap(find.text('寄送重設連結'));
      await tester.pumpAndSettle();
      expect(find.textContaining('我們已寄出重設密碼的連結'), findsOneWidget);
      expect(env.backend.api.calls('POST', '/auth/forgot-password').single.json, {'email': 'reader1@example.com'});
      await env.finish(tester);
    });

    testWidgets('bookshelf asks the server with sort_by', (tester) async {
      await start(tester);
      await env.push(tester, '/bookshelf');
      expect(find.text('書架還是空的'), findsOneWidget);
      expect(env.backend.api.calls('GET', '/bookshelf').last.query, {'sort_by': 'recent'});
      await env.finish(tester);
    });
  });
}
