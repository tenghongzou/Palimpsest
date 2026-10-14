import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/app.dart';
import 'package:palimpsest/features/reader/presentation/providers/reader_provider.dart';
import 'package:palimpsest/features/reader/presentation/widgets/toc_sheet.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.dispose());

  ReaderSettingsNotifier settings(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PalimpsestApp))).read(readerSettingsProvider.notifier);

  Future<void> tapAtFraction(WidgetTester tester, double x) async {
    final size = tester.getSize(find.byType(Scaffold).last);
    await tester.tapAt(Offset(size.width * x, size.height / 2));
    await tester.pumpAndSettle();
  }

  testWidgets('page mode: side taps turn pages and change chapters at the ends', (tester) async {
    await env.pumpApp(tester);
    settings(tester)
      ..updateReadingMode('page')
      ..updateAutoChapter(true);
    await env.push(tester, '/read/${chapterIds[0]}');
    expect(find.text(chapterTitles[0]), findsOneWidget);

    // The test chapter fits on one screen, so the right third moves on.
    await tapAtFraction(tester, 0.9);
    await pumpUntilFound(tester, find.text(chapterTitles[1]));
    expect(find.text(chapterTitles[1]), findsOneWidget);

    await tapAtFraction(tester, 0.1);
    await pumpUntilFound(tester, find.text(chapterTitles[0]));
    expect(find.text(chapterTitles[0]), findsOneWidget);

    // The middle third shows the toolbar instead of turning.
    await tapAtFraction(tester, 0.5);
    expect(find.byTooltip('目錄'), findsOneWidget);
    await env.finish(tester);
  });

  testWidgets('page mode without auto-chapter stays in the chapter', (tester) async {
    await env.pumpApp(tester);
    settings(tester)
      ..updateReadingMode('page')
      ..updateAutoChapter(false);
    await env.push(tester, '/read/${chapterIds[0]}');

    await tapAtFraction(tester, 0.9);
    expect(find.text(chapterTitles[0]), findsOneWidget);
    expect(find.text(chapterTitles[1]), findsNothing);
    await env.finish(tester);
  });

  testWidgets('scroll mode: any tap toggles the toolbar', (tester) async {
    await env.pumpApp(tester);
    settings(tester).updateReadingMode('scroll');
    await env.push(tester, '/read/${chapterIds[0]}');

    await tapAtFraction(tester, 0.9);
    expect(find.byTooltip('目錄'), findsOneWidget);
    expect(find.text(chapterTitles[0]), findsWidgets);
    await env.finish(tester);
  });

  group('toolbars follow the reading theme', () {
    double luminance(Color? c) => c!.computeLuminance();

    Color toolbarColor(WidgetTester tester, String key) => tester.widget<Material>(find.byKey(ValueKey(key))).color!;

    Color iconColor(WidgetTester tester, IconData icon) => IconTheme.of(tester.element(find.byIcon(icon))).color!;

    Color textColor(WidgetTester tester, Finder text) => DefaultTextStyle.of(tester.element(text)).style.color!;

    for (final theme in ['dark', 'black']) {
      testWidgets('$theme: dark toolbars with light foreground, and dark sheets', (tester) async {
        await env.pumpApp(tester);
        settings(tester).updateTheme(theme);
        await env.push(tester, '/read/${chapterIds[0]}');
        await showReaderToolbar(tester);

        for (final key in ['reader-top-toolbar', 'reader-bottom-toolbar']) {
          expect(luminance(toolbarColor(tester, key)), lessThan(0.1), reason: key);
        }
        expect(luminance(iconColor(tester, Icons.arrow_back)), greaterThan(0.4));
        expect(luminance(iconColor(tester, Icons.list)), greaterThan(0.4));
        final title = find.descendant(
            of: find.byKey(const ValueKey('reader-top-toolbar')), matching: find.text(chapterTitles[0]));
        expect(luminance(textColor(tester, title)), greaterThan(0.4));

        // The in-toolbar settings panel is dark too.
        await tester.tap(find.byTooltip('閱讀設定'));
        await tester.pumpAndSettle();
        expect(Theme.of(tester.element(find.text('字體大小'))).brightness, Brightness.dark);
        await tester.tap(find.byTooltip('閱讀設定'));
        await tester.pumpAndSettle();

        // So are the sheets opened from the reader.
        await tester.tap(find.byTooltip('目錄'));
        await tester.pumpAndSettle();
        expect(Theme.of(tester.element(find.byType(TocSheet))).brightness, Brightness.dark);
        expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor!.computeLuminance(), lessThan(0.1));
        await env.finish(tester);
      });
    }

    testWidgets('light themes keep light toolbars', (tester) async {
      await env.pumpApp(tester);
      settings(tester).updateTheme('sepia');
      await env.push(tester, '/read/${chapterIds[0]}');
      await showReaderToolbar(tester);
      for (final key in ['reader-top-toolbar', 'reader-bottom-toolbar']) {
        expect(luminance(toolbarColor(tester, key)), greaterThan(0.7), reason: key);
      }
      expect(luminance(iconColor(tester, Icons.list)), lessThan(0.3));
      await env.finish(tester);
    });
  });
}
