import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/notification_providers.dart';
import '../../../../core/l10n/l10n.dart';

/// App bar bell with the unread count; hidden while signed out.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authStateProvider).valueOrNull == null) return const SizedBox.shrink();
    final count = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: count > 0 ? context.l10n.notificationsUnreadTooltip(count) : context.l10n.notifications,
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(count > 0 ? Icons.notifications : Icons.notifications_outlined),
      ),
    );
  }
}
