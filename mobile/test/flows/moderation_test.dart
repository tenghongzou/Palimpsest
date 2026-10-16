import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

/// Content held for moderation (`status: pending`) is not shown, counted or
/// re-fetched; the author is told it will be public once approved.
const pendingNotice = '已送出，內容將在審核後公開';
const otherUser = '99999999-0000-4000-8000-000000000000';
const threadId = '33333333-0000-4000-8000-000000000001';
const reviewId = '33333333-0000-4000-8000-000000000002';

/// Lets the moderation notice time out.
Future<void> dismissSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  late TestEnv env;

  tearDown(() => env.dispose());

  int listCalls(String path) => env.backend.api.requests.where((r) => r.method == 'GET' && r.path == path).length;
  final commentsPath = '/chapters/${chapterIds[0]}/comments';
  final countsPath = '/chapters/${chapterIds[0]}/comments/paragraph-counts';

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byTooltip('送出留言'));
    await tester.pumpAndSettle();
  }

  group('chapter comments', () {
    Future<void> openChapterComments(WidgetTester tester) async {
      await env.pumpApp(tester);
      await env.push(tester, '/read/${chapterIds[0]}');
      await showReaderToolbar(tester);
      await tester.tap(find.byTooltip('留言'));
      await tester.pumpAndSettle();
    }

    testWidgets('pending is not listed and shows the notice; approved is listed as before', (tester) async {
      env = await TestEnv.create();
      env.backend.commentStatus = 'pending';
      await openChapterComments(tester);
      final lists = listCalls(commentsPath);

      await send(tester, '等待審核的留言');
      expect(find.text(pendingNotice), findsOneWidget);
      expect(find.text('等待審核的留言'), findsNothing);
      expect(find.text('還沒有留言，來搶頭香吧'), findsOneWidget);
      expect(listCalls(commentsPath), lists);
      expect(env.backend.heldComments.single['content'], '等待審核的留言');
      // The input was cleared.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      await dismissSnack(tester);
      env.backend.commentStatus = 'approved';
      await send(tester, '公開的留言');
      expect(find.text(pendingNotice), findsNothing);
      expect(find.text('公開的留言'), findsOneWidget);
      expect(listCalls(commentsPath), lists + 1);
      await env.finish(tester);
    });

    testWidgets('a pending reply is not added to the thread', (tester) async {
      env = await TestEnv.create();
      env.backend.comments.add(commentJson(threadId, '燈塔裡到底是誰？', user: otherUser));
      env.backend.commentStatus = 'pending';
      await openChapterComments(tester);
      final lists = listCalls(commentsPath);

      await tester.tap(find.text('回覆').first);
      await tester.pumpAndSettle();
      await send(tester, '我猜是看守人');
      expect(env.backend.api.calls('POST', commentsPath).last.json['parent_id'], threadId);
      expect(find.text(pendingNotice), findsOneWidget);
      expect(find.text('我猜是看守人'), findsNothing);
      expect(find.text('燈塔裡到底是誰？'), findsOneWidget);
      expect(find.textContaining('回覆 路人'), findsNothing); // reply target cleared
      expect(listCalls(commentsPath), lists);

      await dismissSnack(tester);
      env.backend.commentStatus = 'approved';
      await tester.tap(find.text('回覆').first);
      await tester.pumpAndSettle();
      await send(tester, '公開的回覆');
      expect(find.text(pendingNotice), findsNothing);
      expect(listCalls(commentsPath), lists + 1);
      await env.finish(tester);
    });
  });

  group('paragraph comments', () {
    Finder bubble(int i) => find.byKey(ValueKey('paragraph-comments-$i'));

    testWidgets('pending does not raise the count; approved does', (tester) async {
      env = await TestEnv.create();
      env.backend.comments.add(commentJson(threadId, '第二段好有畫面', paragraphIndex: 1, user: otherUser));
      env.backend.commentStatus = 'pending';
      await env.pumpApp(tester);
      await env.push(tester, '/read/${chapterIds[0]}');
      expect(find.descendant(of: bubble(1), matching: find.text('1')), findsOneWidget);
      final counts = listCalls(countsPath);

      await tester.tap(bubble(1));
      await tester.pumpAndSettle();
      await send(tester, '我也喜歡這段');
      expect(find.text(pendingNotice), findsOneWidget);
      expect(find.text('我也喜歡這段'), findsNothing);
      expect(env.backend.api.calls('POST', commentsPath).last.json['paragraph_index'], 1);
      await tester.tap(find.byTooltip('關閉'));
      await tester.pumpAndSettle();
      expect(listCalls(countsPath), counts);
      expect(find.descendant(of: bubble(1), matching: find.text('1')), findsOneWidget);

      env.backend.commentStatus = 'approved';
      await tester.tap(bubble(1));
      await tester.pumpAndSettle();
      await send(tester, '公開的段落留言');
      expect(find.text('公開的段落留言'), findsOneWidget);
      await tester.tap(find.byTooltip('關閉'));
      await tester.pumpAndSettle();
      expect(listCalls(countsPath), counts + 1);
      expect(find.descendant(of: bubble(1), matching: find.text('2')), findsOneWidget);
      await env.finish(tester);
    });
  });

  group('reviews', () {
    const reviewsPath = '/novels/$novelId/reviews';

    Future<void> openNovel(WidgetTester tester) async {
      await env.pumpApp(tester);
      await env.push(tester, '/novel/$novelId');
      await tester.scrollUntilVisible(find.text('書評'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
    }

    Future<void> submitReview(WidgetTester tester, String button, String title, String content) async {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), title);
      await tester.enterText(fields.at(1), content);
      await tester.tap(find.text('送出'));
      await tester.pumpAndSettle();
    }

    Map<String, dynamic> myReview() => {
          'id': reviewId,
          'user_id': userId,
          'novel_id': novelId,
          'title': '原本的書評',
          'content': '原本的內容',
          'rating': 4.0,
          'like_count': 2,
          'liked_by_me': false,
          'status': 'approved',
          'user': {'id': userId, 'username': 'reader1', 'nickname': '讀者一號'},
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };

    testWidgets('a pending new review is not listed and shows the notice', (tester) async {
      env = await TestEnv.create();
      env.backend.reviewStatus = 'pending';
      await openNovel(tester);
      final lists = listCalls(reviewsPath);

      await submitReview(tester, '撰寫書評', '待審核的書評', '內容');
      expect(env.backend.api.calls('POST', reviewsPath), hasLength(1));
      expect(find.text(pendingNotice), findsOneWidget);
      expect(find.text('已發表書評'), findsNothing);
      expect(find.text('待審核的書評'), findsNothing);
      expect(find.text('還沒有書評，成為第一個評論的讀者吧'), findsOneWidget);
      expect(listCalls(reviewsPath), lists);
      await env.finish(tester);
    });

    testWidgets('an approved new review is listed as before', (tester) async {
      env = await TestEnv.create();
      await openNovel(tester);

      await submitReview(tester, '撰寫書評', '公開的書評', '內容');
      expect(find.text('已發表書評'), findsOneWidget);
      expect(find.text(pendingNotice), findsNothing);
      expect(find.text('公開的書評'), findsOneWidget);
      expect(find.text('編輯我的書評'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-pending-rev1ew00-0000-4000-8000-000000000000')), findsNothing);
      await env.finish(tester);
    });

    testWidgets('a pending edit stays visible to its author, marked as under review', (tester) async {
      env = await TestEnv.create();
      env.backend.reviews.add(myReview());
      env.backend.reviewStatus = 'pending';
      await openNovel(tester);
      expect(find.text('原本的書評'), findsOneWidget);
      final lists = listCalls(reviewsPath);

      await submitReview(tester, '編輯我的書評', '改過的書評', '改過的內容');
      expect(env.backend.api.calls('PUT', '/reviews/$reviewId'), hasLength(1));
      expect(find.text(pendingNotice), findsOneWidget);
      expect(find.text('已更新書評'), findsNothing);
      expect(find.text('改過的書評'), findsOneWidget);
      expect(find.text('原本的書評'), findsNothing);
      expect(find.byKey(const ValueKey('review-pending-$reviewId')), findsOneWidget);
      expect(find.text('審核中'), findsOneWidget);
      expect(find.textContaining('讀者一號'), findsOneWidget);
      // Still the author's: editing again is offered.
      expect(find.text('編輯我的書評'), findsOneWidget);
      expect(listCalls(reviewsPath), lists);
      await env.finish(tester);
    });

    testWidgets('an approved edit refreshes the list as before', (tester) async {
      env = await TestEnv.create();
      env.backend.reviews.add(myReview());
      await openNovel(tester);
      final lists = listCalls(reviewsPath);

      await submitReview(tester, '編輯我的書評', '改過的書評', '改過的內容');
      expect(find.text('已更新書評'), findsOneWidget);
      expect(find.text(pendingNotice), findsNothing);
      expect(find.text('改過的書評'), findsOneWidget);
      expect(find.text('審核中'), findsNothing);
      expect(listCalls(reviewsPath), lists + 1);
      await env.finish(tester);
    });
  });
}
