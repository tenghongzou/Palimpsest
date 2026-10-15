import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/reader/presentation/pages/reader_page.dart';
import 'package:palimpsest/features/reader/presentation/providers/reader_provider.dart';
import 'package:palimpsest/features/reader/presentation/widgets/page_curl.dart';
import 'package:palimpsest/features/reader/presentation/widgets/page_turn_view.dart';

import '../support/fake_api.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

/// Chapters long enough for several pages in the 800x600 test window.
String longContent(int chapter, {int paragraphs = 30, int filler = 50}) => [
      for (var i = 0; i < paragraphs; i++) '第${chapter + 1}章第${i + 1}段：${'霧' * filler}',
    ].join('\n\n');

void useLongChapters(FakeBackend backend, {Duration delay = Duration.zero, int paragraphs = 30, int filler = 50}) {
  backend.api.on('GET', '/chapters/:id', (r) {
    final i = chapterIds.indexOf(r.params['id']!);
    if (i < 0) return FakeResponse.error(404, 40402, 'chapter not found');
    return FakeResponse.ok({...chapterJson(i), 'content': longContent(i, paragraphs: paragraphs, filler: filler)},
        delay: i == 0 ? Duration.zero : delay);
  });
}

final _pageLabel = RegExp(r'^(\d+) / (\d+)$');

/// The page indicators on screen ("2 / 5"), in paint order.
List<String> pageLabels() => find
    .byWidgetPredicate((w) => w is Text && w.data != null && _pageLabel.hasMatch(w.data!))
    .evaluate()
    .map((e) => (e.widget as Text).data!)
    .toList();

int pageCount() => int.parse(_pageLabel.firstMatch(pageLabels().first)!.group(2)!);

String readerChapter(WidgetTester tester) => tester.widget<ReaderPage>(find.byType(ReaderPage)).chapterId;

final _curlBack = find.byKey(const ValueKey('page-curl-back'));
final _curlShadow = find.byKey(const ValueKey('page-curl-shadow'));

/// The curl on screen, or null when the page lies flat.
CurlGeometry? curlGeometry(WidgetTester tester) =>
    (tester.widget<CustomPaint>(_curlBack).painter! as CurlBackPainter).geometry;

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.dispose());

  Future<void> openPaged(WidgetTester tester, String animation,
      {String location = '', bool autoChapter = true, String theme = 'white'}) async {
    await env.pumpApp(tester);
    env.container(tester).read(readerSettingsProvider.notifier)
      ..updateReadingMode('page')
      ..updatePageAnimation(animation)
      ..updateAutoChapter(autoChapter)
      ..updateTheme(theme);
    await env.push(tester, location.isEmpty ? '/read/${chapterIds[0]}' : location);
  }

  Size screen(WidgetTester tester) => tester.getSize(find.byType(Scaffold).last);

  Future<void> tapAt(WidgetTester tester, double x) async {
    final size = screen(tester);
    await tester.tapAt(Offset(size.width * x, size.height / 2));
  }

  group('tap turning', () {
    for (final animation in ['none', 'slide', 'cover', 'curl']) {
      testWidgets('with $animation', (tester) async {
        useLongChapters(env.backend);
        await openPaged(tester, animation);
        final n = pageCount();
        expect(n, greaterThan(2));
        expect(pageLabels(), ['1 / $n']);
        final restX = tester.getTopLeft(find.text('1 / $n')).dx;

        await tapAt(tester, 0.9);
        await tester.pump(); // the animation starts on this frame
        await tester.pump(const Duration(milliseconds: 120));
        switch (animation) {
          case 'none':
            expect(pageLabels(), ['2 / $n']);
          case 'slide':
            // Both pages move together.
            expect(pageLabels(), ['1 / $n', '2 / $n']);
            expect(tester.getTopLeft(find.text('1 / $n')).dx, lessThan(restX));
          case 'cover':
            // The new page slides in over the old one, which stays put.
            expect(pageLabels(), ['1 / $n', '2 / $n']);
            expect(tester.getTopLeft(find.text('1 / $n')).dx, restX);
            expect(tester.getTopLeft(find.text('2 / $n')).dx, greaterThan(restX));
          case 'curl':
            // The current page curls up over the next one, which lies
            // underneath; neither moves.
            expect(pageLabels(), ['2 / $n', '1 / $n']);
            expect(tester.getTopLeft(find.text('1 / $n')).dx, restX);
            expect(tester.getTopLeft(find.text('2 / $n')).dx, restX);
            final curl = curlGeometry(tester)!;
            // Lifted by the lower corner.
            expect(curl.corner.dy, curl.size.height);
            expect(curl.point.dy, lessThan(curl.size.height));
            expect(_curlShadow, findsOneWidget);
        }
        await tester.pumpAndSettle();
        expect(pageLabels(), ['2 / $n']);
        expect(find.textContaining('第1章第1段'), findsNothing);

        await tapAt(tester, 0.1);
        await tester.pumpAndSettle();
        expect(pageLabels(), ['1 / $n']);
        expect(find.text(chapterTitles[0]), findsOneWidget);

        // Quick taps each turn a page, even mid-animation.
        await tapAt(tester, 0.9);
        await tester.pump(const Duration(milliseconds: 50));
        await tapAt(tester, 0.9);
        await tester.pumpAndSettle();
        expect(pageLabels(), ['3 / $n']);
        await env.finish(tester);
      });
    }

    for (final animation in ['slide', 'curl']) {
      testWidgets('reduce motion turns instantly whatever the setting ($animation)', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        useLongChapters(env.backend);
        await openPaged(tester, animation);
        final n = pageCount();
        await tapAt(tester, 0.9);
        await tester.pump();
        expect(pageLabels(), ['2 / $n']);
        expect(_curlBack, findsNothing);
        // A swipe too.
        await tester.drag(find.byType(PageTurnView), const Offset(-300, 0));
        await tester.pump();
        expect(pageLabels(), ['3 / $n']);
        expect(_curlBack, findsNothing);
        await env.finish(tester);
      });
    }
  });

  group('swipe turning', () {
    testWidgets('the page follows the finger, then turns or settles back', (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'slide');
      final n = pageCount();
      final size = screen(tester);
      final restX = tester.getTopLeft(find.text('1 / $n')).dx;

      // A short drag shows the next page moving in, and settles back.
      var gesture = await tester.startGesture(Offset(size.width * 0.7, size.height / 2));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(pageLabels(), ['1 / $n', '2 / $n']);
      expect(tester.getTopLeft(find.text('1 / $n')).dx, lessThan(restX - 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pageLabels(), ['1 / $n']);
      expect(tester.getTopLeft(find.text('1 / $n')).dx, restX);

      // Past the threshold it turns.
      gesture = await tester.startGesture(Offset(size.width * 0.8, size.height / 2));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pageLabels(), ['2 / $n']);

      // A quick flick turns even when short; right goes back.
      await tester.fling(find.byType(PageTurnView), const Offset(-100, 0), 1500);
      await tester.pumpAndSettle();
      expect(pageLabels(), ['3 / $n']);
      await tester.fling(find.byType(PageTurnView), const Offset(250, 0), 1500);
      await tester.pumpAndSettle();
      expect(pageLabels(), ['2 / $n']);

      // Vertical drags do not turn pages.
      await tester.drag(find.byType(PageTurnView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(pageLabels(), ['2 / $n']);
      expect(find.byTooltip('目錄'), findsNothing);
      await env.finish(tester);
    });

    testWidgets('with no animation a swipe turns at once', (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'none');
      final n = pageCount();
      await tester.drag(find.byType(PageTurnView), const Offset(-300, 0));
      await tester.pump();
      expect(pageLabels(), ['2 / $n']);
      await tester.drag(find.byType(PageTurnView), const Offset(300, 0));
      await tester.pump();
      expect(pageLabels(), ['1 / $n']);
      await env.finish(tester);
    });

    testWidgets('the first page of the first chapter does not move back', (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'slide');
      final n = pageCount();
      final size = screen(tester);
      final gesture = await tester.startGesture(Offset(size.width * 0.3, size.height / 2));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(pageLabels(), ['1 / $n']);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(readerChapter(tester), chapterIds[0]);
      await env.finish(tester);
    });
  });

  group('curl', () {
    testWidgets('a drag from the lower corner curls the page after the finger, then completes', (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'curl');
      final n = pageCount();
      final size = tester.getSize(find.byType(PageTurnView));
      final origin = tester.getTopLeft(find.byType(PageTurnView));

      final gesture = await tester.startGesture(origin + Offset(size.width * 0.9, size.height * 0.9));
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      double? lastFold;
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(-40, -5));
        await tester.pump(const Duration(milliseconds: 16));
        final curl = curlGeometry(tester)!;
        expect(curl.corner, Offset(size.width, size.height));
        // Tilted: the corner has risen off the bottom edge.
        expect(curl.point.dy, lessThan(size.height));
        // The fold moves left with the finger.
        if (lastFold != null) expect(curl.mid.dx, lessThan(lastFold));
        lastFold = curl.mid.dx;
      }
      expect(pageLabels(), ['2 / $n', '1 / $n']);
      final clip = tester.widget<ClipPath>(
          find.ancestor(of: find.text('1 / $n'), matching: find.byType(ClipPath)).first);
      expect(clip.clipper, isA<CurlClipper>());
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pageLabels(), ['2 / $n']);
      expect(_curlBack, findsNothing);
      await env.finish(tester);
    });

    testWidgets('a short drag from the middle folds straight and settles back', (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'curl');
      final n = pageCount();
      final size = tester.getSize(find.byType(PageTurnView));
      final origin = tester.getTopLeft(find.byType(PageTurnView));

      final gesture = await tester.startGesture(origin + Offset(size.width * 0.7, size.height / 2));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-60, 20));
      await tester.pump();
      final curl = curlGeometry(tester)!;
      expect(curl.normal.dx, closeTo(1, 1e-9));
      expect(curl.point.dy, curl.corner.dy);
      expect(pageLabels(), ['2 / $n', '1 / $n']);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // On its way back.
      expect(_curlBack, findsOneWidget);
      await tester.pumpAndSettle();
      expect(pageLabels(), ['1 / $n']);
      expect(_curlBack, findsNothing);
      await env.finish(tester);
    });

    testWidgets('dragging back uncurls the previous page onto the current one', (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'curl');
      final n = pageCount();
      await tapAt(tester, 0.9);
      await tester.pumpAndSettle();
      expect(pageLabels(), ['2 / $n']);

      final size = tester.getSize(find.byType(PageTurnView));
      final origin = tester.getTopLeft(find.byType(PageTurnView));
      final gesture = await tester.startGesture(origin + Offset(size.width * 0.2, size.height * 0.85));
      await gesture.moveBy(const Offset(30, 0));
      double? lastFold;
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump(const Duration(milliseconds: 16));
        final curl = curlGeometry(tester)!;
        // The fold moves right with the finger, flattening the previous page.
        if (lastFold != null) expect(curl.mid.dx, greaterThan(lastFold));
        lastFold = curl.mid.dx;
      }
      // The current page lies underneath, the previous one comes over it.
      expect(pageLabels(), ['2 / $n', '1 / $n']);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pageLabels(), ['1 / $n']);
      expect(_curlBack, findsNothing);

      // A fling back from the first page of the first chapter does nothing.
      await tester.fling(find.byType(PageTurnView), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(pageLabels(), ['1 / $n']);
      expect(readerChapter(tester), chapterIds[0]);
      await env.finish(tester);
    });

    testWidgets('curls across a chapter edge into the next chapter', (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'curl', location: '/read/${chapterIds[0]}?at=end');
      final n = pageCount();
      expect(pageLabels(), ['$n / $n']);
      await tapAt(tester, 0.9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text(chapterTitles[1]), findsOneWidget);
      expect(_curlBack, findsOneWidget);
      await tester.pumpAndSettle();
      expect(readerChapter(tester), chapterIds[1]);
      expect(pageLabels().single, startsWith('1 / '));
      await env.finish(tester);
    });
  });

  group('chapter edges', () {
    testWidgets('turning past the last page animates into the next chapter and back to its last page',
        (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'slide', location: '/read/${chapterIds[0]}?at=end');
      final n = pageCount();
      expect(pageLabels(), ['$n / $n']);

      await tapAt(tester, 0.9);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      // Mid-turn the next chapter's first page is already showing.
      expect(find.text(chapterTitles[1]), findsOneWidget);
      await tester.pumpAndSettle();
      expect(readerChapter(tester), chapterIds[1]);
      expect(find.text(chapterTitles[1]), findsOneWidget);
      final m = pageCount();
      expect(pageLabels(), ['1 / $m']);

      // Swiping back lands on the previous chapter's last page.
      await tester.fling(find.byType(PageTurnView), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(readerChapter(tester), chapterIds[0]);
      expect(pageLabels(), ['$n / $n']);
      await env.finish(tester);
    });

    testWidgets('a chapter still loading shows a loading page, then its first page', (tester) async {
      useLongChapters(env.backend, delay: const Duration(seconds: 3));
      await openPaged(tester, 'cover', location: '/read/${chapterIds[0]}?at=end');
      final n = pageCount();

      final size = screen(tester);
      final gesture = await tester.startGesture(Offset(size.width * 0.9, size.height / 2));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-300, 0));
      await tester.pump();
      expect(find.text(chapterTitles[1]), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(pageLabels(), ['$n / $n']);

      await gesture.up();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(readerChapter(tester), chapterIds[1]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(pageLabels().single, startsWith('1 / '));
      expect(find.textContaining('第2章第1段'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('without auto-chapter the last page stays put', (tester) async {
      useLongChapters(env.backend);
      await openPaged(tester, 'slide', location: '/read/${chapterIds[0]}?at=end', autoChapter: false);
      final n = pageCount();
      await tapAt(tester, 0.9);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageTurnView), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(readerChapter(tester), chapterIds[0]);
      expect(pageLabels(), ['$n / $n']);
      await env.finish(tester);
    });
  });

  testWidgets('long-press paragraph comments, bubbles and the middle-tap toolbar work in page mode', (tester) async {
    useLongChapters(env.backend);
    env.backend.comments.add(commentJson('55555555-0000-4000-8000-000000000001', '第一段好看', paragraphIndex: 0));
    await openPaged(tester, 'slide');

    final bubble = find.byKey(const ValueKey('paragraph-comments-0'));
    expect(bubble, findsOneWidget);
    await tester.tap(bubble);
    await tester.pumpAndSettle();
    expect(find.text('第 1 段的留言'), findsOneWidget);
    expect(find.text('第一段好看'), findsOneWidget);
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('目錄'), findsNothing);
    expect(pageLabels().single, startsWith('1 / '));

    await tester.longPress(find.textContaining('第1章第2段'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 段的留言'), findsOneWidget);
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    expect(pageLabels().single, startsWith('1 / '));

    await tapAt(tester, 0.5);
    await tester.pumpAndSettle();
    expect(find.byTooltip('目錄'), findsOneWidget);
    // With the toolbar shown, side taps close it instead of turning.
    await tapAt(tester, 0.9);
    await tester.pumpAndSettle();
    expect(find.byTooltip('目錄'), findsNothing);
    expect(pageLabels().single, startsWith('1 / '));
    await env.finish(tester);
  });

  testWidgets('dark themes paint every page, moving or not, on the theme background', (tester) async {
    useLongChapters(env.backend);
    await openPaged(tester, 'cover', theme: 'black');
    await tapAt(tester, 0.9);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final boxes = tester.widgetList<ColoredBox>(
        find.descendant(of: find.byType(PageTurnView), matching: find.byType(ColoredBox)));
    expect(boxes, hasLength(2));
    expect(boxes.map((b) => b.color).toSet(), {const Color(0xFF000000)});
    await tester.pumpAndSettle();
    await env.finish(tester);
  });

  testWidgets('changing the font size keeps the reader at the same text', (tester) async {
    useLongChapters(env.backend, paragraphs: 80, filler: 8);
    await openPaged(tester, 'none');
    for (var i = 0; i < 3; i++) {
      await tapAt(tester, 0.9);
      await tester.pump();
    }
    expect(pageLabels().single, startsWith('4 / '));
    // The first paragraph on this page.
    final first = find.textContaining(RegExp(r'^　　第1章第\d+段')).evaluate().map((e) {
      final text = (e.widget as Text).textSpan!.toPlainText();
      return int.parse(RegExp(r'第(\d+)段').firstMatch(text)!.group(1)!);
    }).reduce((a, b) => a < b ? a : b);

    env.container(tester).read(readerSettingsProvider.notifier).updateFontSize(28);
    await tester.pumpAndSettle();
    expect(pageLabels().single, isNot(startsWith('4 / ')));
    expect(find.textContaining('第1章第$first段'), findsOneWidget);

    env.container(tester).read(readerSettingsProvider.notifier).updateFontSize(14);
    await tester.pumpAndSettle();
    expect(find.textContaining('第1章第$first段'), findsOneWidget);
    await env.finish(tester);
  });

  testWidgets('switching from page to scroll mode keeps the position', (tester) async {
    useLongChapters(env.backend, paragraphs: 80, filler: 8);
    await openPaged(tester, 'none');
    for (var i = 0; i < 3; i++) {
      await tapAt(tester, 0.9);
      await tester.pump();
    }
    expect(find.textContaining('第1章第1段'), findsNothing);
    env.container(tester).read(readerSettingsProvider.notifier).updateReadingMode('scroll');
    await tester.pumpAndSettle();
    expect(pageLabels(), isEmpty);
    // Not scrolled back to the top.
    expect(find.textContaining('第1章第1段').hitTestable(), findsNothing);
    await env.finish(tester);
  });
}
