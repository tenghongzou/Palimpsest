import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../../../core/l10n/l10n.dart';

class ReadingHistoryPage extends ConsumerWidget {
  const ReadingHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.readingHistory)),
      body: user == null
          ? EmptyState(
              icon: Icons.history,
              message: l.historySignInPrompt,
              actionLabel: l.authLogin,
              onAction: () => context.push('/login'),
            )
          : Consumer(builder: (context, ref, _) {
              final state = ref.watch(readingHistoryProvider);
              final notifier = ref.read(readingHistoryProvider.notifier);
              return PagedListView(
                state: state,
                onLoadMore: notifier.loadMore,
                onRefresh: notifier.refresh,
                empty: Text(l.historyEmpty),
                itemBuilder: (context, entry, _) {
                  final chapter = entry.chapterNumber != null
                      ? chapterLabel(entry.chapterNumber!, entry.chapterTitle ?? '', l)
                      : entry.chapterTitle ?? '';
                  return ListTile(
                    leading: NovelCover(url: entry.novel?.coverUrl, width: 40, height: 56),
                    title: Text(entry.novel?.title ?? l.unknownNovel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '$chapter\n${formatRelative(entry.readAt, l)}'
                      '${entry.duration > 0 ? ' · ${l.historyReadFor(formatDuration(entry.duration, l))}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => context.push('/read/${entry.chapterId}'),
                  );
                },
              );
            }),
    );
  }
}
