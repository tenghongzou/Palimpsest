import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/reader/presentation/widgets/page_curl.dart';

void main() {
  const size = Size(400, 800);

  double area(List<Offset> polygon) {
    var sum = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2;
  }

  test('the corner is picked from where the drag starts', () {
    expect(CurlCorner.fromY(100, 800), CurlCorner.top);
    expect(CurlCorner.fromY(400, 800), CurlCorner.middle);
    expect(CurlCorner.fromY(700, 800), CurlCorner.bottom);
  });

  test('flat at rest', () {
    for (final corner in CurlCorner.values) {
      expect(CurlGeometry.at(size, 0, corner), isNull);
    }
  });

  test('from the middle of the edge the fold is a straight vertical line that follows the finger', () {
    for (final p in [0.1, 0.5, 0.8]) {
      final g = CurlGeometry.at(size, p, CurlCorner.middle, dy: 120)!;
      expect(g.normal.dx, closeTo(1, 1e-9));
      expect(g.normal.dy, closeTo(0, 1e-9));
      expect(g.mid.dx, closeTo(400 * (1 - p), 1e-9));
      expect(area(g.flat), closeTo(400 * (1 - p) * 800, 1e-6));
      // The flap is the folded part mirrored onto the flat side.
      expect(area(g.flap), closeTo(area(g.folded), 1e-6));
      for (final x in g.flap) {
        expect(g.side(x), lessThanOrEqualTo(1e-9));
      }
    }
  });

  test('from a corner the fold is tilted and the corner rises', () {
    final bottom = CurlGeometry.at(size, 0.5, CurlCorner.bottom)!;
    expect(bottom.corner, const Offset(400, 800));
    expect(bottom.point.dy, lessThan(800));
    expect(bottom.normal.dy, greaterThan(0));
    final top = CurlGeometry.at(size, 0.5, CurlCorner.top)!;
    expect(top.corner, const Offset(400, 0));
    expect(top.point.dy, greaterThan(0));
    expect(top.normal.dy, lessThan(0));
    // Pulling the finger up tilts a bottom curl further.
    final pulled = CurlGeometry.at(size, 0.5, CurlCorner.bottom, dy: -200)!;
    expect(pulled.point.dy, lessThan(bottom.point.dy));
    // The shapes cover the page exactly.
    expect(area(bottom.flat) + area(bottom.folded), closeTo(400 * 800, 1e-6));
  });

  test('the page stays attached at the spine and leaves the screen completely at the end', () {
    for (final corner in CurlCorner.values) {
      for (var p = 0.05; p <= 1.0; p += 0.05) {
        final g = CurlGeometry.at(size, p, corner, dy: -300)!;
        expect((g.point - Offset(0, g.corner.dy)).distance, lessThanOrEqualTo(400 + 1e-6));
      }
      final end = CurlGeometry.at(size, 1, corner)!;
      expect(area(end.flat), closeTo(0, 1e-6));
      for (final x in end.flap) {
        expect(x.dx, lessThanOrEqualTo(1e-6));
      }
    }
  });

  test('the reflection mirrors points across the fold line', () {
    final g = CurlGeometry.at(size, 0.4, CurlCorner.bottom, dy: -50)!;
    final m = g.reflection;
    Offset apply(Offset x) => Offset(m[0] * x.dx + m[4] * x.dy + m[12], m[1] * x.dx + m[5] * x.dy + m[13]);
    expect((apply(g.corner) - g.point).distance, closeTo(0, 1e-6));
    expect((apply(g.mid) - g.mid).distance, closeTo(0, 1e-6));
  });
}
