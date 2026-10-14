import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ReadingHistoryPage extends ConsumerWidget {
  const ReadingHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('閱讀記錄')),
      body: user == null
          ? EmptyState(
              icon: Icons.history,
              message: '登入後即可查看閱讀記錄',
              actionLabel: '登入',
              onAction: () => context.push('/login'),
            )
          : Consumer(builder: (context, ref, _) {
              final state = ref.watch(readingHistoryProvider);
              final notifier = ref.read(readingHistoryProvider.notifier);
              return PagedListView(
                state: state,
                onLoadMore: notifier.loadMore,
                onRefresh: notifier.refresh,
                empty: const Text('還沒有閱讀記錄'),
                itemBuilder: (context, entry, _) {
                  final chapter = entry.chapterNumber != null
                      ? '第${entry.chapterNumber}章 ${entry.chapterTitle ?? ''}'
                      : entry.chapterTitle ?? '';
                  return ListTile(
                    leading: NovelCover(url: entry.novel?.coverUrl, width: 40, height: 56),
                    title: Text(entry.novel?.title ?? '未知作品', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '$chapter\n${formatRelative(entry.readAt)}${entry.duration > 0 ? ' · 讀了 ${formatDuration(entry.duration)}' : ''}',
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
