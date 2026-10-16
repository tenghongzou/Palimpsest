import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_config.dart';

/// Palimpsest brand colours (see shared/brand/README.md).
abstract final class BrandColors {
  static const blue = Color(0xFF1890FF);

  /// Wordmark on light backgrounds.
  static const ink = Color(0xFF1F2937);

  /// Page beige: wordmark on dark backgrounds, splash background.
  static const paper = Color(0xFFF5F0E0);
}

enum BrandLogoVariant { horizontal, stacked, mark }

/// The Palimpsest logo, drawn from the vector assets in assets/brand/
/// (copies of shared/brand/logo-mark.svg and wordmark.svg).
///
/// The mark keeps its own colours; the wordmark follows the theme
/// ([BrandColors.ink] on light, [BrandColors.paper] on dark) unless
/// [wordmarkColor] is given. Every variant is sized by its [height] and
/// keeps the proportions of the matching shared/brand SVG.
class BrandLogo extends StatelessWidget {
  static const markAsset = 'assets/brand/logo-mark.svg';
  static const wordmarkAsset = 'assets/brand/wordmark.svg';

  final BrandLogoVariant variant;
  final double height;
  final Color? wordmarkColor;

  const BrandLogo({super.key, required this.variant, required this.height, this.wordmarkColor});

  /// Mark and wordmark side by side: app bars, the navigation rail.
  const BrandLogo.horizontal({super.key, this.height = 28, this.wordmarkColor})
      : variant = BrandLogoVariant.horizontal;

  /// Mark above the wordmark: sign-in page.
  const BrandLogo.stacked({super.key, this.height = 120, this.wordmarkColor})
      : variant = BrandLogoVariant.stacked;

  /// The square mark alone, for sizes too small for the wordmark.
  const BrandLogo.mark({super.key, double size = 32})
      : variant = BrandLogoVariant.mark,
        height = size,
        wordmarkColor = null;

  /// Width over height of [variant].
  double get aspectRatio => _layouts[variant]!.canvas.aspectRatio;

  /// Width the logo takes at [height].
  double get width => height * aspectRatio;

  static Color defaultWordmarkColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? BrandColors.paper : BrandColors.ink;

  @override
  Widget build(BuildContext context) {
    final layout = _layouts[variant]!;
    final scale = height / layout.canvas.height;
    final mark = SvgPicture.asset(markAsset, excludeFromSemantics: true);
    final wordmarkRect = layout.wordmark;
    return Semantics(
      label: AppConfig.appName,
      image: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fromRect(rect: _scaled(layout.mark, scale), child: mark),
            if (wordmarkRect != null)
              Positioned.fromRect(
                rect: _scaled(wordmarkRect, scale),
                child: SvgPicture.asset(
                  wordmarkAsset,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                  colorFilter: ColorFilter.mode(wordmarkColor ?? defaultWordmarkColor(context), BlendMode.srcIn),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Rect _scaled(Rect r, double s) => Rect.fromLTWH(r.left * s, r.top * s, r.width * s, r.height * s);
}

class _LogoLayout {
  /// The logo's viewBox, in shared/brand SVG units.
  final Size canvas;
  final Rect mark;

  /// Where wordmark.svg's viewBox (35 -830 5668 1080) lands, if present.
  final Rect? wordmark;

  const _LogoLayout(this.canvas, this.mark, [this.wordmark]);
}

// Derived from the transforms in shared/brand: logo-horizontal.svg places the
// wordmark glyphs at translate(1309.79 747.52) scale(0.61174), and
// logo-stacked.svg places the mark at x=358.4 and the glyphs at
// translate(-10.75 1485.77) scale(0.30713).
const _layouts = <BrandLogoVariant, _LogoLayout>{
  BrandLogoVariant.mark: _LogoLayout(Size(1024, 1024), Rect.fromLTWH(0, 0, 1024, 1024)),
  BrandLogoVariant.horizontal: _LogoLayout(
    Size(4799, 1024),
    Rect.fromLTWH(0, 0, 1024, 1024),
    Rect.fromLTWH(1331.199, 239.776, 3467.342, 660.679),
  ),
  BrandLogoVariant.stacked: _LogoLayout(
    Size(1741, 1563),
    Rect.fromLTWH(358.4, 0, 1024, 1024),
    Rect.fromLTWH(0, 1230.852, 1740.813, 331.700),
  ),
};
