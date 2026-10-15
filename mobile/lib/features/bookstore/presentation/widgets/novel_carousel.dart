import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/entities/novel.dart';

/// A novel's cover with its title and a short line under it (the author, or
/// why it is recommended), for [NovelCarousel].
class NovelCoverTile extends StatelessWidget {
  static const width = 104.0;
  static const coverHeight = 146.0;
  static const _titleSize = 13.0;
  static const _subtitleSize = 11.0;
  static const _lineHeight = 1.3;

  final Novel novel;
  final String subtitle;
  final VoidCallback? onTap;

  const NovelCoverTile({super.key, required this.novel, required this.subtitle, this.onTap});

  /// The height a tile needs with the current text scale.
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return coverHeight + 6 + scaler.scale(_titleSize) * _lineHeight * 2 + 2 + scaler.scale(_subtitleSize) * _lineHeight * 2 + 4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NovelCover(url: novel.coverUrl, width: width, height: coverHeight),
            const SizedBox(height: 6),
            Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: _titleSize, height: _lineHeight, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: _subtitleSize, height: _lineHeight, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of [NovelCoverTile]s (mouse drags scroll it
/// too, on desktop).
class NovelCarousel extends StatelessWidget {
  final List<NovelCoverTile> tiles;

  const NovelCarousel({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: NovelCoverTile.heightFor(context),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tiles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => tiles[i],
        ),
      ),
    );
  }
}
