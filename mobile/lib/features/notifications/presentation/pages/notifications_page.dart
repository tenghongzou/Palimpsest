import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../notification_text.dart';
import '../providers/notification_providers.dart';
import '../../../../core/l10n/l10n.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(unreadCountProvider.notifier).refresh());
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(notificationsProvider.notifier).refresh(),
      ref.read(unreadCountProvider.notifier).refresh(),
    ]);
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      final now = DateTime.now().toUtc();
      ref.read(notificationsProvider.notifier).updateItems((items) => items.map((n) => n.markedRead(now)).toList());
      ref.read(unreadCountProvider.notifier).set(0);
      if (mounted) showSnack(context, context.l10n.notificationsMarkedAllRead);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e, context.l10n));
    }
  }

  /// Marks it read (best effort, without waiting) and opens what it links to.
  void _open(AppNotification n) {
    if (!n.isRead) {
      ref.read(notificationsProvider.notifier).updateItems(
          (items) => items.map((x) => x.id == n.id ? x.markedRead() : x).toList());
      ref.read(unreadCountProvider.notifier).decrement();
      ref.read(notificationRepositoryProvider).markRead(n.id).catchError((_) {
        // Offline: the server still counts it; the next refresh corrects the badge.
      });
    }
    final location = n.location;
    if (location != null) {
      context.push(location);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(n.localizedTitle(context.l10n)),
        content: SingleChildScrollView(child: Text(n.localizedBody(context.l10n) ?? '', style: const TextStyle(height: 1.6))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonClose))],
      ),
    );
  }

  Future<void> _delete(AppNotification n) async {
    final notifier = ref.read(notificationsProvider.notifier);
    final unread = ref.read(unreadCountProvider.notifier);
    notifier.updateItems((items) => items.where((x) => x.id != n.id).toList());
    if (!n.isRead) unread.decrement();
    try {
      await ref.read(notificationRepositoryProvider).delete(n.id);
    } catch (e) {
      if (httpStatus(e) == 404) return; // already gone
      if (mounted) showSnack(context, context.l10n.deleteFailed(describeError(e, context.l10n)));
      await notifier.refresh();
      await unread.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final l = context.l10n;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.notifications)),
        body: EmptyState(
          icon: Icons.notifications_none,
          message: l.notificationsSignInPrompt,
          actionLabel: l.authLogin,
          onAction: () => context.push('/login'),
        ),
      );
    }

    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final unread = ref.watch(unreadCountProvider);
    final hasUnread = unread > 0 || state.items.any((n) => !n.isRead);

    Widget body;
    if (state.items.isEmpty && state.error != null && isNetworkError(state.error!)) {
      body = EmptyState(
        icon: Icons.wifi_off,
        message: l.notificationsOffline,
        actionLabel: l.commonRetry,
        onAction: _refresh,
      );
    } else {
      body = PagedListView<AppNotification>(
        state: state,
        onLoadMore: notifier.loadMore,
        onRefresh: _refresh,
        empty: Text(l.notificationsEmpty),
        itemBuilder: (context, n, _) => Dismissible(
          key: ValueKey('notification-${n.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _delete(n),
          child: _NotificationTile(notification: n, onTap: () => _open(n)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        actions: [
          TextButton(onPressed: hasUnread ? _markAllRead : null, child: Text(l.notificationsMarkAllRead)),
        ],
      ),
      body: body,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _icon {
    switch (notification.type) {
      case NotificationTypes.chapterUpdate:
        return Icons.auto_stories_outlined;
      case NotificationTypes.commentReply:
        return Icons.forum_outlined;
    }
    return Icons.campaign_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final title = n.localizedTitle(context.l10n);
    final body = n.localizedBody(context.l10n);
    final scheme = Theme.of(context).colorScheme;
    final unread = !n.isRead;
    return Material(
      color: unread ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, color: unread ? scheme.primary : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(formatRelative(n.createdAt, context.l10n), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (unread)
                Semantics(
                  label: context.l10n.notificationUnread,
                  child: Container(
                    key: ValueKey('unread-dot-${n.id}'),
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
