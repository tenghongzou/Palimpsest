import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n.dart';

/// Marks the author's own review or comment that awaits moderation
/// (「審核中」). Only the author sees such items.
class PendingBadge extends StatelessWidget {
  const PendingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(4)),
      child: Text(
        context.l10n.moderationPendingBadge,
        style: TextStyle(fontSize: 11, color: scheme.onTertiaryContainer),
      ),
    );
  }
}
