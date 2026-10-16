import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/core/widgets/brand_logo.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

ColorFilter? _wordmarkFilter(WidgetTester tester) => tester
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .singleWhere((p) => (p.bytesLoader as SvgAssetLoader).assetName == BrandLogo.wordmarkAsset)
    .colorFilter;

void main() {
  group('BrandLogo', () {
    testWidgets('horizontal keeps the shared SVG proportions and draws mark + wordmark', (tester) async {
      await tester.pumpWidget(_host(const BrandLogo.horizontal(height: 40)));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(BrandLogo));
      expect(size.height, 40);
      expect(size.width, closeTo(40 * 4799 / 1024, 0.01));
      expect(find.byType(SvgPicture), findsNWidgets(2));
    });

    testWidgets('stacked keeps the shared SVG proportions', (tester) async {
      await tester.pumpWidget(_host(const BrandLogo.stacked(height: 156.3)));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(BrandLogo));
      expect(size.width, closeTo(174.1, 0.01));
      expect(find.byType(SvgPicture), findsNWidgets(2));
    });

    testWidgets('mark is a square without the wordmark', (tester) async {
      await tester.pumpWidget(_host(const BrandLogo.mark(size: 36)));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(BrandLogo)), const Size(36, 36));
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('wordmark follows the theme brightness unless overridden', (tester) async {
      await tester.pumpWidget(_host(const BrandLogo.horizontal()));
      expect(_wordmarkFilter(tester), const ColorFilter.mode(BrandColors.ink, BlendMode.srcIn));

      await tester.pumpWidget(_host(const BrandLogo.horizontal(), brightness: Brightness.dark));
      await tester.pumpAndSettle(); // MaterialApp animates theme changes
      expect(_wordmarkFilter(tester), const ColorFilter.mode(BrandColors.paper, BlendMode.srcIn));

      await tester.pumpWidget(_host(const BrandLogo.horizontal(wordmarkColor: Colors.red)));
      expect(_wordmarkFilter(tester), const ColorFilter.mode(Colors.red, BlendMode.srcIn));
    });

    testWidgets('is announced as a single "Palimpsest" image', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const BrandLogo.stacked()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Palimpsest'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(BrandLogo)),
        matchesSemantics(label: 'Palimpsest', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('bundled SVG assets load', (tester) async {
      for (final asset in [BrandLogo.markAsset, BrandLogo.wordmarkAsset]) {
        final svg = await rootBundle.loadString(asset);
        expect(svg, startsWith('<svg'));
      }
    });
  });
}
