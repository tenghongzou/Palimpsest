import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

/// Content held for moderation (`status: pending`) tells its author it will
/// be public once approved. The server lists it for its author only, so it
/// shows (muted, marked 「審核中」) with edit/delete but no like, reply or
/// report; paragraph counts keep counting approved comments only.
const pendingNotice = '已送出，內容將在審核後公開';
const otherUser = '99999999-0000-4000-8000-000000000000';
const threadId = '33333333-0000-4000-8000-000000000001';
const reviewId = '33333333-0000-4000-8000-000000000002';
const heldId = '33333333-0000-4000-8000-000000000003';

/// Lets the moderation notice time out.
Future<void> dismissSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// The comment tile showing [text].
Finder commentTile(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CommentTile'),
    );

/// The review card showing [text].
Finder reviewCard(String text) => find.ancestor(of: find.text(text), matching: find.byType(Card));

/// Opens the more menu inside [tile] and returns the labels it offers.
Future<List<String>> menuOf(WidgetTester tester, Finder tile) async {
  await tester.tap(find.descendant(of: tile, matching: find.byTooltip('更多')));
  await tester.pumpAndSettle();
  final labels = [
    for (final label in ['編輯', '刪除', '檢舉'])
      if (find.descendant(of: find.byType(PopupMenuItem<String>), matching: find.text(label)).evaluate().isNotEmpty) label,
  ];
  return labels;
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

  void expectHeldComment(String text, {required bool pending}) {
    final tile = commentTile(text);
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('審核中')), pending ? findsOneWidget : findsNothing);
    expect(find.descendant(of: tile, matching: find.text('回覆')), pending ? findsNothing : findsOneWidget);
    expect(find.descendant(of: tile, matching: find.byIcon(Icons.thumb_up_outlined)), pending ? findsNothing : findsOneWidget);
  }

  group('chapter comments', () {
    Future<void> openChapterComments(WidgetTester tester) async {
      await env.pumpApp(tester);
      await env.push(tester, '/read/${chapterIds[0]}');
      await showReaderToolbar(tester);
      await tester.tap(find.byTooltip('留言'));
      await tester.pumpAndSettle();
    }

    testWidgets('a pending comment shows the notice and is listed for its author, under review', (tester) async {
      env = await TestEnv.create();
      env.backend.commentStatus = 'pending';
      await openChapterComments(tester);
      final lists = listCalls(commentsPath);

      await send(tester, '等待審核的留言');
      expect(find.text(pendingNotice), findsOneWidget);
      expect(env.backend.heldComments.single['content'], '等待審核的留言');
      expect(listCalls(commentsPath), lists + 1);
      expectHeldComment('等待審核的留言', pending: true);
      expect(find.byKey(ValueKey('comment-pending-${env.backend.heldComments.single['id']}')), findsOneWidget);
      // The input was cleared.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      // The author can delete it, but not report it.
      expect(await menuOf(tester, commentTile('等待審核的留言')), ['刪除']);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await dismissSnack(tester);
      env.backend.commentStatus = 'approved';
      await send(tester, '公開的留言');
      expect(find.text(pendingNotice), findsNothing);
      expectHeldComment('公開的留言', pending: false);
      expectHeldComment('等待審核的留言', pending: true);
      expect(listCalls(commentsPath), lists + 2);
      await env.finish(tester);
    });

    testWidgets('the author can delete a pending comment', (tester) async {
      env = await TestEnv.create();
      env.backend.heldComments.add(commentJson(heldId, '想收回的留言', status: 'pending'));
      await openChapterComments(tester);
      expectHeldComment('想收回的留言', pending: true);

      expect(await menuOf(tester, commentTile('想收回的留言')), ['刪除']);
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      expect(env.backend.api.calls('DELETE', '/comments/$heldId'), hasLength(1));
      expect(env.backend.heldComments, isEmpty);
      expect(find.text('想收回的留言'), findsNothing);
      expect(find.text('還沒有留言，來搶頭香吧'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('others\' pending comments are never listed; signed out sees no pending', (tester) async {
      env = await TestEnv.create(signedIn: false);
      env.backend.heldComments
        ..add(commentJson(heldId, '別人的待審留言', user: otherUser, status: 'pending'))
        ..add(commentJson('33333333-0000-4000-8000-000000000004', '自己的待審留言', status: 'pending'));
      await openChapterComments(tester);
      expect(find.text('別人的待審留言'), findsNothing);
      expect(find.text('自己的待審留言'), findsNothing);
      expect(find.text('還沒有留言，來搶頭香吧'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('a pending reply is listed in its thread, under review', (tester) async {
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
      expect(find.textContaining('回覆 路人'), findsNothing); // reply target cleared
      expect(listCalls(commentsPath), lists + 1);
      // The thread keeps its actions; the pending reply has none but delete.
      expectHeldComment('燈塔裡到底是誰？', pending: false);
      expectHeldComment('我猜是看守人', pending: true);
      expect(await menuOf(tester, commentTile('燈塔裡到底是誰？')), ['檢舉']);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      expect(await menuOf(tester, commentTile('我猜是看守人')), ['刪除']);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await dismissSnack(tester);
      env.backend.commentStatus = 'approved';
      await tester.tap(find.descendant(of: commentTile('燈塔裡到底是誰？'), matching: find.text('回覆')));
      await tester.pumpAndSettle();
      await send(tester, '公開的回覆');
      expect(find.text(pendingNotice), findsNothing);
      expectHeldComment('公開的回覆', pending: false);
      expect(listCalls(commentsPath), lists + 2);
      await env.finish(tester);
    });
  });

  group('paragraph comments', () {
    Finder bubble(int i) => find.byKey(ValueKey('paragraph-comments-$i'));

    testWidgets('a pending one is listed for its author but does not raise the count', (tester) async {
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
      expectHeldComment('我也喜歡這段', pending: true);
      expect(env.backend.api.calls('POST', commentsPath).last.json['paragraph_index'], 1);
      await tester.tap(find.byTooltip('關閉'));
      await tester.pumpAndSettle();
      expect(listCalls(countsPath), counts);
      expect(find.descendant(of: bubble(1), matching: find.text('1')), findsOneWidget);

      env.backend.commentStatus = 'approved';
      await tester.tap(bubble(1));
      await tester.pumpAndSettle();
      // Still listed when the sheet is opened again.
      expectHeldComment('我也喜歡這段', pending: true);
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

    Map<String, dynamic> myReview({String status = 'approved'}) => {
          'id': reviewId,
          'user_id': userId,
          'novel_id': novelId,
          'title': '原本的書評',
          'content': '原本的內容',
          'rating': 4.0,
          'like_count': 2,
          'liked_by_me': false,
          'status': status,
          'user': {'id': userId, 'username': 'reader1', 'nickname': '讀者一號'},
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };

    void expectPendingReview(String title, {required bool pending}) {
      final card = reviewCard(title);
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('審核中')), pending ? findsOneWidget : findsNothing);
      expect(find.descendant(of: card, matching: find.byIcon(Icons.thumb_up_outlined)), pending ? findsNothing : findsOneWidget);
    }

    testWidgets('a pending new review is listed for its author, who can then edit it', (tester) async {
      env = await TestEnv.create();
      env.backend.reviewStatus = 'pending';
      await openNovel(tester);
      final lists = listCalls(reviewsPath);

      await submitReview(tester, '撰寫書評', '待審核的書評', '內容');
      expect(env.backend.api.calls('POST', reviewsPath), hasLength(1));
      expect(find.text(pendingNotice), findsOneWidget);
      expect(find.text('已發表書評'), findsNothing);
      expect(listCalls(reviewsPath), lists + 1);
      expectPendingReview('待審核的書評', pending: true);
      expect(find.byKey(const ValueKey('review-pending-rev1ew00-0000-4000-8000-000000000000')), findsOneWidget);
      // Counted as the author's: editing is offered instead of a second post.
      expect(find.text('編輯我的書評'), findsOneWidget);
      expect(find.text('撰寫書評'), findsNothing);

      await dismissSnack(tester);
      await submitReview(tester, '編輯我的書評', '再改一次', '內容');
      expect(env.backend.api.calls('POST', reviewsPath), hasLength(1));
      expect(env.backend.api.calls('PUT', '/reviews/rev1ew00-0000-4000-8000-000000000000'), hasLength(1));
      expect(find.text('你已經評論過這本書，可以編輯原本的書評'), findsNothing);
      expectPendingReview('再改一次', pending: true);
      await env.finish(tester);
    });

    testWidgets('a pending review returned by the list is the author\'s: edit and delete, no like or report', (tester) async {
      env = await TestEnv.create();
      env.backend.heldReviews.add(myReview(status: 'pending'));
      await openNovel(tester);
      expectPendingReview('原本的書評', pending: true);
      expect(find.text('編輯我的書評'), findsOneWidget);
      expect(find.text('撰寫書評'), findsNothing);

      expect(await menuOf(tester, reviewCard('原本的書評')), ['編輯', '刪除']);
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      expect(env.backend.api.calls('DELETE', '/reviews/$reviewId'), hasLength(1));
      expect(find.text('已刪除書評'), findsOneWidget);
      expect(find.text('原本的書評'), findsNothing);
      expect(find.text('撰寫書評'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('others\' pending reviews are never listed', (tester) async {
      env = await TestEnv.create();
      env.backend.heldReviews.add({...myReview(status: 'pending'), 'user_id': otherUser});
      await openNovel(tester);
      expect(find.text('原本的書評'), findsNothing);
      expect(find.text('撰寫書評'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('an approved new review is listed as before', (tester) async {
      env = await TestEnv.create();
      await openNovel(tester);

      await submitReview(tester, '撰寫書評', '公開的書評', '內容');
      expect(find.text('已發表書評'), findsOneWidget);
      expect(find.text(pendingNotice), findsNothing);
      expectPendingReview('公開的書評', pending: false);
      expect(find.text('編輯我的書評'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-pending-rev1ew00-0000-4000-8000-000000000000')), findsNothing);
      await env.finish(tester);
    });

    testWidgets('a pending edit stays visible to its author, marked as under review', (tester) async {
      env = await TestEnv.create();
      env.backend.reviews.add(myReview());
      env.backend.reviewStatus = 'pending';
      await openNovel(tester);
      expectPendingReview('原本的書評', pending: false);
      final lists = listCalls(reviewsPath);

      await submitReview(tester, '編輯我的書評', '改過的書評', '改過的內容');
      expect(env.backend.api.calls('PUT', '/reviews/$reviewId'), hasLength(1));
      expect(find.text(pendingNotice), findsOneWidget);
      expect(find.text('已更新書評'), findsNothing);
      expect(find.text('原本的書評'), findsNothing);
      expectPendingReview('改過的書評', pending: true);
      expect(find.byKey(const ValueKey('review-pending-$reviewId')), findsOneWidget);
      expect(find.textContaining('讀者一號'), findsOneWidget);
      // Still the author's: editing again is offered.
      expect(find.text('編輯我的書評'), findsOneWidget);
      expect(listCalls(reviewsPath), lists + 1);
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
      expectPendingReview('改過的書評', pending: false);
      expect(find.text('審核中'), findsNothing);
      expect(listCalls(reviewsPath), lists + 1);
      await env.finish(tester);
    });
  });
}
