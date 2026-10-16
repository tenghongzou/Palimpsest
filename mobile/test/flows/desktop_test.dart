import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/widgets/brand_logo.dart';
import 'package:palimpsest/features/bookshelf/presentation/pages/bookshelf_page.dart';
import 'package:palimpsest/features/bookstore/presentation/pages/home_page.dart';
import 'package:palimpsest/features/profile/presentation/pages/profile_page.dart';
import 'package:palimpsest/features/reader/presentation/pages/reader_page.dart';
import 'package:palimpsest/features/reader/presentation/providers/reader_provider.dart';
import 'package:palimpsest/features/search/presentation/pages/search_page.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';
import 'reader_page_turn_test.dart' show pageCount, pageLabels, readerChapter, useLongChapters;

/// Desktop: the wide layout's navigation rail, and keyboard and mouse
/// wheel shortcuts.
void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.dispose());

  void useWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('wide layout', () {
    testWidgets('narrow windows keep the bottom navigation bar', (tester) async {
      await env.pumpApp(tester); // the 800x600 test window
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      // The home app bar shows the horizontal logo instead of a text title.
      final appBarLogo = tester.widget<BrandLogo>(find.descendant(of: find.byType(AppBar), matching: find.byType(BrandLogo)));
      expect(appBarLogo.variant, BrandLogoVariant.horizontal);
      expect(find.bySemanticsLabel('Palimpsest'), findsOneWidget);
      await env.finish(tester);
    });

    testWidgets('wide windows show a navigation rail that switches tabs', (tester) async {
      useWindow(tester, const Size(1000, 800));
      await env.pumpApp(tester);
      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(rail.selectedIndex, 0);
      // The compact rail's header is the square mark alone.
      final railLogo = tester.widget<BrandLogo>(find.descendant(of: find.byType(NavigationRail), matching: find.byType(BrandLogo)));
      expect(railLogo.variant, BrandLogoVariant.mark);
      // The rail carries the logo, so the home app bar shows a plain title.
      expect(find.descendant(of: find.byType(AppBar), matching: find.byType(BrandLogo)), findsNothing);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('首頁')), findsOneWidget);
      // Same destinations and labels as the bottom bar.
      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('書架')), findsOneWidget);
      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('我的')), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('書架')));
      await tester.pumpAndSettle();
      expect(find.byType(BookshelfPage), findsOneWidget);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 1);

      await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('我的')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 2);

      // Pages opened from a tab cover the rail.
      await env.push(tester, '/settings');
      expect(find.byType(NavigationRail), findsNothing);
      await env.finish(tester);
    });

    testWidgets('large windows extend the rail with labels', (tester) async {
      useWindow(tester, const Size(1400, 900));
      await env.pumpApp(tester);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isTrue);
      // The extended rail's header is the horizontal logo.
      final railLogo = tester.widget<BrandLogo>(find.descendant(of: find.byType(NavigationRail), matching: find.byType(BrandLogo)));
      expect(railLogo.variant, BrandLogoVariant.horizontal);
      await env.finish(tester);
    });

    testWidgets('the reader keeps a readable text column on wide windows', (tester) async {
      useWindow(tester, const Size(1600, 900));
      useLongChapters(env.backend);
      await env.pumpApp(tester);
      env.container(tester).read(readerSettingsProvider.notifier).updateReadingMode('scroll');
      await env.push(tester, '/read/${chapterIds[0]}');
      final text = find.textContaining('第1章第1段');
      expect(tester.getTopLeft(text).dx, greaterThanOrEqualTo(400));
      expect(tester.getTopRight(text).dx, lessThanOrEqualTo(1200));
      await env.finish(tester);
    });
  });

  group('reader keys', () {
    Future<void> openReader(WidgetTester tester, String mode, {String location = ''}) async {
      useLongChapters(env.backend);
      await env.pumpApp(tester);
      env.container(tester).read(readerSettingsProvider.notifier)
        ..updateReadingMode(mode)
        ..updatePageAnimation('none')
        ..updateAutoChapter(true);
      await env.push(tester, location.isEmpty ? '/read/${chapterIds[0]}' : location);
    }

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {LogicalKeyboardKey? modifier}) async {
      if (modifier != null) await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(key);
      if (modifier != null) await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
    }

    testWidgets('page mode: arrows, Page Up/Down and Space turn pages', (tester) async {
      await openReader(tester, 'page');
      final n = pageCount();
      expect(pageLabels(), ['1 / $n']);

      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(pageLabels(), ['2 / $n']);
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(pageLabels(), ['3 / $n']);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(pageLabels(), ['2 / $n']);
      await press(tester, LogicalKeyboardKey.pageUp);
      expect(pageLabels(), ['1 / $n']);
      await press(tester, LogicalKeyboardKey.space);
      expect(pageLabels(), ['2 / $n']);
      await press(tester, LogicalKeyboardKey.space, modifier: LogicalKeyboardKey.shiftLeft);
      expect(pageLabels(), ['1 / $n']);
      await env.finish(tester);
    });

    testWidgets('page mode: the mouse wheel turns pages', (tester) async {
      await openReader(tester, 'page');
      final n = pageCount();
      final center = tester.getCenter(find.byType(ReaderPage));
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(center));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();
      expect(pageLabels(), ['2 / $n']);
      await env.finish(tester);
    });

    testWidgets('brackets and Ctrl+Left/Right change chapters', (tester) async {
      await openReader(tester, 'page');
      await press(tester, LogicalKeyboardKey.bracketRight);
      expect(readerChapter(tester), chapterIds[1]);
      await press(tester, LogicalKeyboardKey.arrowRight, modifier: LogicalKeyboardKey.controlLeft);
      expect(readerChapter(tester), chapterIds[2]);
      await press(tester, LogicalKeyboardKey.bracketLeft);
      expect(readerChapter(tester), chapterIds[1]);
      await press(tester, LogicalKeyboardKey.arrowLeft, modifier: LogicalKeyboardKey.controlLeft);
      expect(readerChapter(tester), chapterIds[0]);
      // Nothing before the first chapter.
      await press(tester, LogicalKeyboardKey.bracketLeft);
      expect(readerChapter(tester), chapterIds[0]);
      await env.finish(tester);
    });

    testWidgets('scroll mode: keys scroll the text', (tester) async {
      await openReader(tester, 'scroll');
      final scrollable = find.descendant(of: find.byType(ReaderPage), matching: find.byType(Scrollable));
      double offset() => tester.state<ScrollableState>(scrollable.first).position.pixels;
      expect(offset(), 0);

      await press(tester, LogicalKeyboardKey.arrowDown);
      final line = offset();
      expect(line, greaterThan(0));
      await press(tester, LogicalKeyboardKey.pageDown);
      final screen = offset() - line;
      expect(screen, greaterThan(line * 3));
      await press(tester, LogicalKeyboardKey.space);
      expect(offset(), closeTo(line + 2 * screen, 1));
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(offset(), closeTo(line + screen, 1));
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(offset(), closeTo(screen, 1));
      await env.finish(tester);
    });

    testWidgets('Esc closes a sheet, then the toolbar, then the reader', (tester) async {
      await openReader(tester, 'page');
      await showReaderToolbar(tester);
      expect(find.byKey(const ValueKey('reader-top-toolbar')), findsOneWidget);

      await tester.tap(find.byTooltip('目錄'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('reader-top-toolbar')), findsOneWidget);

      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const ValueKey('reader-top-toolbar')), findsNothing);
      expect(find.byType(ReaderPage), findsOneWidget);

      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ReaderPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      await env.finish(tester);
    });
  });

  group('global keys', () {
    Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {LogicalKeyboardKey? modifier, String? character}) async {
      if (modifier != null) await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(key, character: character);
      if (modifier != null) await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
    }

    testWidgets('Ctrl+F and / open search, but not while typing', (tester) async {
      await env.pumpApp(tester);
      await press(tester, LogicalKeyboardKey.keyF, modifier: LogicalKeyboardKey.controlLeft);
      expect(find.byType(SearchPage), findsOneWidget);

      // The search field has focus: Esc leaves it, a second Esc goes back.
      expect(tester.testTextInput.hasAnyClients, isTrue);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(SearchPage), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(SearchPage), findsNothing);

      await press(tester, LogicalKeyboardKey.slash, character: '/');
      expect(find.byType(SearchPage), findsOneWidget);
      await press(tester, LogicalKeyboardKey.escape);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(SearchPage), findsNothing);

      // In a text field "/" and Ctrl+F are text editing, not shortcuts.
      await env.push(tester, '/login');
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.slash, character: '/');
      await press(tester, LogicalKeyboardKey.keyF, modifier: LogicalKeyboardKey.controlLeft);
      expect(find.byType(SearchPage), findsNothing);
      await env.finish(tester);
    });

    testWidgets('Alt+Left goes back', (tester) async {
      await env.pumpApp(tester);
      await env.push(tester, '/novel/$novelId');
      expect(find.byType(HomePage), findsNothing);
      await press(tester, LogicalKeyboardKey.arrowLeft, modifier: LogicalKeyboardKey.altLeft);
      expect(find.byType(HomePage), findsOneWidget);
      // Nothing to go back to: stays put.
      await press(tester, LogicalKeyboardKey.arrowLeft, modifier: LogicalKeyboardKey.altLeft);
      expect(find.byType(HomePage), findsOneWidget);
      await env.finish(tester);
    });
  });
}
