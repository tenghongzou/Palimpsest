import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:go_router/go_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../bookshelf/presentation/providers/bookshelf_provider.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../domain/entities/reading_stats.dart';
import '../providers/profile_provider.dart';
import '../../../../core/l10n/l10n.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navProfile), actions: const [NotificationBell()]),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildNotLoggedIn(context),
        data: (user) {
          if (user == null) return _buildNotLoggedIn(context);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(readingStatsProvider);
              await ref.read(authStateProvider.notifier).refreshUser();
            },
            child: ReadableInset(
              builder: (context, inset) => ListView(
              padding: EdgeInsets.symmetric(horizontal: 16 + inset, vertical: 16),
              children: [
                _UserCard(user: user),
                const SizedBox(height: 16),
                const _StatsCard(),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      _menu(context, Icons.book_outlined, context.l10n.shelfTitle, () => context.go('/bookshelf')),
                      _menu(context, Icons.notifications_outlined, context.l10n.notifications,
                          () => context.push('/notifications')),
                      _menu(context, Icons.history, context.l10n.readingHistory, () => context.push('/history')),
                      _menu(context, Icons.bookmarks_outlined, context.l10n.myBookmarks, () => context.push('/bookmarks')),
                      _menu(context, Icons.download_outlined, context.l10n.downloadsTitle, () => context.push('/downloads')),
                      _menu(context, Icons.settings_outlined, context.l10n.settings, () => context.push('/settings'),
                          divider: false),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    ref.read(bookshelfProvider.notifier).reset();
                    if (context.mounted) context.go('/');
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(context.l10n.logout),
                ),
              ],
            ),
            ),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 2),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool divider = true}) {
    return Column(
      children: [
        ListTile(leading: Icon(icon), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: onTap),
        if (divider) const Divider(height: 1),
      ],
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return ReadableInset(
      builder: (context, inset) => ListView(
      padding: EdgeInsets.symmetric(horizontal: inset),
      children: [
        const SizedBox(height: 48),
        EmptyState(
          icon: Icons.person_outline,
          message: context.l10n.notSignedIn,
          actionLabel: context.l10n.authLogin,
          onAction: () => context.push('/login'),
        ),
        const SizedBox(height: 24),
        Card(
          margin: const EdgeInsets.all(16),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(context.l10n.downloadsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/downloads'),
              ),
              const Divider(height: 1),
              // Language and reading settings work without an account.
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(context.l10n.settings),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user.displayName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null ? Text(name.isEmpty ? '?' : name.characters.first, style: const TextStyle(fontSize: 24)) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('@${user.username}', style: TextStyle(color: Colors.grey.shade600)),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(user.bio!, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _periods = ['daily', 'weekly', 'monthly'];

String _periodLabel(String period, AppLocalizations l) => switch (period) {
      'weekly' => l.statsPeriodWeekly,
      'monthly' => l.statsPeriodMonthly,
      _ => l.statsPeriodDaily,
    };

class _StatsCard extends ConsumerStatefulWidget {
  const _StatsCard();

  @override
  ConsumerState<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends ConsumerState<_StatsCard> {
  String _period = 'daily';

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(readingStatsProvider(_period));
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: stats.when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => SizedBox(height: 60, child: Center(child: Text(l.statsUnavailable))),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(l.statsWords, formatWordCount(s.totalReadWords, l)),
                  _stat(l.statsTime, formatDuration(s.totalReadSeconds, l)),
                  _stat(l.statsChapters, formatNumber(s.chaptersRead, l)),
                  _stat(l.statsNovels, formatNumber(s.novelsRead, l)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // The period is shown by the dropdown next to it.
                  Text(l.statsTime, style: Theme.of(context).textTheme.labelLarge),
                  DropdownButton<String>(
                    value: _period,
                    underline: const SizedBox(),
                    items: _periods
                        .map((e) => DropdownMenuItem(value: e, child: Text(_periodLabel(e, l))))
                        .toList(),
                    onChanged: (v) => setState(() => _period = v ?? _period),
                  ),
                ],
              ),
              _BucketBars(buckets: s.buckets),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      );
}

class _BucketBars extends StatelessWidget {
  final List<StatsBucket> buckets;

  const _BucketBars({required this.buckets});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();
    final max = buckets.map((b) => b.seconds).fold<int>(0, (a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets.map((b) {
          final ratio = max == 0 ? 0.0 : b.seconds / max;
          final start = b.start.toLocal();
          return Expanded(
            child: Tooltip(
              message: context.l10n.statsBucket(
                  DateFormat.Md(intlLocaleOf(context.l10n)).format(start), formatDuration(b.seconds, context.l10n)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 4 + 64 * ratio,
                      decoration: BoxDecoration(
                        color: b.seconds == 0 ? Colors.grey.shade300 : color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${start.month}/${start.day}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
