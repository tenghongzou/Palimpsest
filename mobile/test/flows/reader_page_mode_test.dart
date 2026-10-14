import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/app.dart';
import 'package:palimpsest/features/reader/presentation/providers/reader_provider.dart';

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
}
