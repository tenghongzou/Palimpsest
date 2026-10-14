import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';
import 'test_app.dart';

/// Browse → open novel → read chapter 1 → next chapter → bookmark.
/// Shared by test/flows/core_flow_test.dart (runs with `flutter test`) and
/// integration_test/app_flow_test.dart (runs on a device).
Future<void> runCoreReadingFlow(WidgetTester tester, TestEnv env) async {
  await env.pumpApp(tester);

  // Home page sections come from GET /home.
  expect(find.text('編輯推薦'), findsOneWidget);
  await tester.tap(find.text('霧港燈塔').first);
  await tester.pumpAndSettle();

  // Novel detail.
  expect(find.text('小說詳情'), findsOneWidget);
  expect(find.text('開始閱讀'), findsOneWidget);
  await tester.tap(find.text('開始閱讀'));
  await tester.pumpAndSettle();

  // Reader on chapter 1, which is cached for offline reading.
  expect(find.text(chapterTitles[0]), findsOneWidget);
  expect(find.textContaining('第1章的第一段'), findsOneWidget);
  expect(await env.store.getChapter(chapterIds[0]), isNotNull);

  // Next chapter through the toolbar.
  await showReaderToolbar(tester);
  await tester.tap(find.widgetWithText(TextButton, '下一章').last);
  await tester.pumpAndSettle();
  expect(find.text(chapterTitles[1]), findsWidgets);
  expect(find.textContaining('第2章的第一段'), findsOneWidget);

  // Bookmark the current paragraph; it is stored locally and synced.
  await showReaderToolbar(tester);
  await tester.tap(find.byTooltip('加入書籤'));
  await tester.pumpAndSettle();
  expect(find.textContaining('已加入書籤'), findsOneWidget);

  final bookmarks = await env.store.bookmarks(novelId: novelId);
  expect(bookmarks, hasLength(1));
  expect(bookmarks.single.chapterId, chapterIds[1]);
  expect(env.backend.bookmarks.keys, contains(bookmarks.single.id));

  // Opening each chapter reported reading progress.
  final reported = env.backend.progressUpdates.map((p) => p['chapter_id']).toList();
  expect(reported, containsAll([chapterIds[0], chapterIds[1]]));

  await env.finish(tester);
}
