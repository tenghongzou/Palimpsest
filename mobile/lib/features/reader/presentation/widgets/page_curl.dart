import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Which corner of the page's outer edge a curl lifts: the one nearest to
/// where the drag started, or the whole edge ([middle], a vertical fold).
enum CurlCorner {
  top,
  middle,
  bottom;

  /// The corner for a drag that starts at height [y] of a page [height] tall.
  static CurlCorner fromY(double y, double height) =>
      y < height / 3 ? top : (y > height * 2 / 3 ? bottom : middle);
}

/// The shape of a page curled over from its right edge.
///
/// The page's [corner] (on the right edge) has been lifted and laid down at
/// [point]; the page folds along the perpendicular bisector of the two (the
/// fold line, through [mid] with unit [normal] pointing towards the corner).
/// [flat] is the part of the page still lying flat, [folded] the part that was
/// lifted (where the page underneath now shows) and [flap] that part as it
/// lies folded over, showing the back of the page.
class CurlGeometry {
  final Size size;
  final Offset corner;
  final Offset point;
  final Offset mid;
  final Offset normal;
  final List<Offset> flat;
  final List<Offset> folded;
  final List<Offset> flap;

  CurlGeometry._(this.size, this.corner, this.point, this.mid, this.normal, this.flat, this.folded, this.flap);

  /// The curl of a page of [size] at [progress] (0 lying flat, 1 turned
  /// completely off to the left), lifted at [cornerAt]. [dy] is how far the
  /// finger has moved vertically since the drag started, which tilts a corner
  /// curl further. Null while the page lies flat.
  ///
  /// The fold line moves across the page as fast as the finger does: it is at
  /// `width * (1 - progress)` along the corner's edge.
  static CurlGeometry? at(Size size, double progress, CurlCorner cornerAt, {double dy = 0}) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return null;
    final p = progress.clamp(0.0, 1.0);
    final cy = switch (cornerAt) {
      CurlCorner.top => 0.0,
      CurlCorner.bottom => h,
      CurlCorner.middle => h / 2,
    };
    final corner = Offset(w, cy);
    var py = cy;
    if (cornerAt != CurlCorner.middle) {
      // A corner pulled sideways also rises off the page a little; the tilt
      // fades in at the start and out at the end, so the page lies exactly
      // flat at rest and leaves the screen exactly at the end.
      final fade = math.min(1.0, p / 0.15) * math.min(1.0, (1 - p) / 0.35);
      final lift = math.min(h * 0.1, w * 0.3);
      final pull = dy.clamp(-h * 0.4, h * 0.4);
      if (cornerAt == CurlCorner.bottom) {
        py = math.min(h, h + (-lift + pull) * fade);
      } else {
        py = math.max(0.0, (lift + pull) * fade);
      }
    }
    var point = Offset(w - 2 * p * w, py);
    // The page stays attached at the spine (the left edge): the corner can
    // get no further from the spine's end than the page is wide.
    final spine = Offset(0, cy);
    final reach = point - spine;
    if (reach.distance > w) point = spine + reach * (w / reach.distance);

    final lifted = corner - point;
    if (lifted.distance < 0.5) return null;
    final normal = lifted / lifted.distance;
    final mid = (corner + point) / 2;
    double side(Offset x) => (x.dx - mid.dx) * normal.dx + (x.dy - mid.dy) * normal.dy;
    final page = [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)];
    final flat = _clip(page, (x) => -side(x));
    final folded = _clip(page, side);
    final flap = [for (final x in folded) x - normal * (2 * side(x))];
    return CurlGeometry._(size, corner, point, mid, normal, flat, folded, flap);
  }

  /// The part of [polygon] where [f] is not negative (one Sutherland-Hodgman
  /// pass against a half-plane).
  static List<Offset> _clip(List<Offset> polygon, double Function(Offset) f) {
    final out = <Offset>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      final fa = f(a), fb = f(b);
      if (fa >= 0) out.add(a);
      if ((fa >= 0) != (fb >= 0)) out.add(Offset.lerp(a, b, fa / (fa - fb))!);
    }
    return out;
  }

  /// Signed distance of [x] from the fold line, positive on the corner's side.
  double side(Offset x) => (x.dx - mid.dx) * normal.dx + (x.dy - mid.dy) * normal.dy;

  /// How far the flap reaches from the fold line.
  double get flapDepth => flap.fold(0.0, (d, x) => math.max(d, -side(x)));

  /// How far the fold line has moved in from the corner.
  double get liftedBy => (corner - point).distance / 2;

  static Path _path(List<Offset> polygon) => polygon.length < 3 ? Path() : (Path()..addPolygon(polygon, true));

  Path get flatPath => _path(flat);
  Path get foldedPath => _path(folded);
  Path get flapPath => _path(flap);

  /// The transform that mirrors the page across the fold line (column-major).
  Float64List get reflection {
    final nx = normal.dx, ny = normal.dy;
    final k = 2 * (mid.dx * nx + mid.dy * ny);
    return Float64List.fromList([
      1 - 2 * nx * nx, -2 * nx * ny, 0, 0,
      -2 * nx * ny, 1 - 2 * ny * ny, 0, 0,
      0, 0, 1, 0,
      k * nx, k * ny, 0, 1,
    ]);
  }
}

/// Clips the curling page to the part still lying flat.
class CurlClipper extends CustomClipper<Path> {
  final CurlGeometry geometry;

  const CurlClipper(this.geometry);

  @override
  Path getClip(Size size) => geometry.flatPath;

  @override
  bool shouldReclip(CurlClipper oldClipper) => !identical(oldClipper.geometry, geometry);
}

/// The shadow the curl casts on the page underneath, along the fold line.
class CurlShadowPainter extends CustomPainter {
  final CurlGeometry? geometry;
  final bool dark;

  const CurlShadowPainter(this.geometry, {required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    if (g == null || g.folded.length < 3) return;
    final width = (g.liftedBy * 0.35).clamp(4.0, 36.0);
    final shadow = Color.fromRGBO(0, 0, 0, dark ? 0.6 : 0.32);
    canvas.save();
    canvas.clipPath(g.foldedPath);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
            g.mid, g.mid + g.normal * width, [shadow, shadow.withValues(alpha: 0)], const [0, 1]),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CurlShadowPainter oldDelegate) =>
      !identical(oldDelegate.geometry, geometry) || oldDelegate.dark != dark;
}

/// The back of the curling page, folded over it: paper tinted a little off
/// the page colour, the page's content mirrored and faint when [content] (a
/// snapshot of the page) is there, and shading across the fold.
class CurlBackPainter extends CustomPainter {
  final CurlGeometry? geometry;
  final Color paper;
  final ui.Image? content;
  final bool dark;

  const CurlBackPainter(this.geometry, {required this.paper, required this.dark, this.content});

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    if (g == null || g.flap.length < 3) return;
    final path = g.flapPath;
    canvas.drawShadow(path, const Color(0xFF000000), 3, false);
    final back = Color.lerp(paper, dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000), dark ? 0.06 : 0.03)!;
    canvas.drawPath(path, Paint()..color = back);

    final image = content;
    if (image != null) {
      canvas.save();
      canvas.clipPath(path);
      canvas.transform(g.reflection);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & g.size,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, dark ? 0.12 : 0.14)
          ..filterQuality = FilterQuality.low,
      );
      canvas.restore();
    }

    // Darker right at the fold, a highlight where the paper bends, fading
    // towards the flap's edge.
    final depth = math.max(g.flapDepth, 1.0);
    final shade = Color.fromRGBO(0, 0, 0, dark ? 0.5 : 0.22);
    final light = Color.fromRGBO(255, 255, 255, dark ? 0.08 : 0.35);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          g.mid,
          g.mid - g.normal * depth,
          [shade, light, light.withValues(alpha: 0), shade.withValues(alpha: dark ? 0.25 : 0.08)],
          const [0, 0.12, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(CurlBackPainter oldDelegate) =>
      !identical(oldDelegate.geometry, geometry) ||
      oldDelegate.content != content ||
      oldDelegate.paper != paper ||
      oldDelegate.dark != dark;
}
