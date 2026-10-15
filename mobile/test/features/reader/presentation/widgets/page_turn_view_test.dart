import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/reader/presentation/widgets/page_curl.dart';
import 'package:palimpsest/features/reader/presentation/widgets/page_turn_view.dart';

void main() {
  final curlBack = find.byKey(const ValueKey('page-curl-back'));

  for (final effect in PageTurnEffect.values) {
    testWidgets('controller.turn with $effect builds each page once, not per frame', (tester) async {
      final builds = <int, int>{};
      final changes = <int>[];
      final controller = PageTurnController();
      await tester.pumpWidget(MaterialApp(
        home: PageTurnView(
          page: 0,
          pageCount: 5,
          effect: effect,
          background: Colors.white,
          controller: controller,
          canLeave: (_) => false,
          onLeave: (_) {},
          onPageChanged: changes.add,
          pageBuilder: (context, index) {
            builds[index] = (builds[index] ?? 0) + 1;
            return Center(child: Text('page $index'));
          },
        ),
      ));
      controller.turn(1);
      await tester.pump();
      var frames = 0;
      CurlGeometry? previous;
      while (controller.isTurning) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
        if (effect == PageTurnEffect.curl && controller.isTurning) {
          final geometry = (tester.widget<CustomPaint>(curlBack).painter! as CurlBackPainter).geometry;
          // The fold sweeps across the page from right to left.
          if (previous != null && geometry != null) {
            expect(geometry.mid.dx, lessThanOrEqualTo(previous.mid.dx + 1e-6));
          }
          previous = geometry ?? previous;
        }
      }
      if (effect == PageTurnEffect.none) {
        expect(frames, 0);
      } else {
        // About 300ms (350ms for the curl).
        expect(frames, inInclusiveRange(15, 25));
        expect(previous != null, effect == PageTurnEffect.curl);
      }
      expect(changes, [1]);
      expect(find.text('page 1'), findsOneWidget);
      expect(find.text('page 0'), findsNothing);
      expect(builds[0], 1);
      expect(builds[1], 1);
      expect(curlBack, findsNothing);
    });
  }

  testWidgets('a new pageBuilder rebuilds the pages', (tester) async {
    var label = 'a';
    Widget view() => MaterialApp(
          home: PageTurnView(
            page: 0,
            pageCount: 2,
            effect: PageTurnEffect.curl,
            background: Colors.white,
            canLeave: (_) => false,
            onLeave: (_) {},
            onPageChanged: (_) {},
            pageBuilder: (context, index) => Text('$label$index'),
          ),
        );
    await tester.pumpWidget(view());
    expect(find.text('a0'), findsOneWidget);
    label = 'b';
    await tester.pumpWidget(view());
    expect(find.text('b0'), findsOneWidget);
    // Let the snapshot timer run out.
    await tester.pump(const Duration(seconds: 1));
  });
}
