import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// AppBottomNav, AppNavShell and the readable-width helpers.
export 'adaptive_layout.dart';

/// A novel cover with a placeholder when there is no image.
class NovelCover extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const NovelCover({super.key, this.url, this.width = 60, this.height = 84});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Icon(Icons.book, color: Colors.grey, size: width / 2.5),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
    );
  }
}

/// A centred message with an optional action, for empty or signed-out states.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
