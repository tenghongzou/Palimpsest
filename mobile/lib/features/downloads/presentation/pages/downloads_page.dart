import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/offline_store.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/network/api_error.dart';
import '../../data/download_manager.dart';
import '../../../../core/l10n/l10n.dart';

/// Size of chapters cached while reading (not downloaded explicitly).
final readingCacheSizeProvider = FutureProvider.autoDispose<int>((ref) async {
  return (await ref.read(offlineStoreProvider)()).cacheSizeBytes(downloaded: false);
});

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider).values.where((t) => t.isActive || t.status == DownloadStatus.failed).toList();
    final downloaded = ref.watch(downloadedNovelsProvider);
    final cacheSize = ref.watch(readingCacheSizeProvider).valueOrNull;

    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.downloadsTitle)),
      body: downloaded.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.downloadsLoadFailed('$e'))),
        data: (novels) {
          final totalBytes = novels.fold<int>(0, (sum, n) => sum + n.sizeBytes);
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(l.downloadsSummary(novels.length, formatBytes(totalBytes))),
                subtitle: cacheSize == null ? null : Text(l.downloadsCache(formatBytes(cacheSize))),
                trailing: TextButton(
                  onPressed: cacheSize == null || cacheSize == 0
                      ? null
                      : () async {
                          await (await ref.read(offlineStoreProvider)()).clearCachedChapters();
                          ref.invalidate(readingCacheSizeProvider);
                          if (context.mounted) showSnack(context, context.l10n.downloadsCacheCleared);
                        },
                  child: Text(l.downloadsClearCache),
                ),
              ),
              const Divider(height: 1),
              ...tasks.map((t) => _TaskTile(task: t)),
              if (novels.isEmpty && tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: EmptyState(icon: Icons.download_outlined, message: l.downloadsEmpty),
                ),
              ...novels.map((n) => _DownloadedTile(novel: n)),
            ],
          );
        },
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final DownloadTask task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider.notifier);
    final failed = task.status == DownloadStatus.failed;
    final l = context.l10n;
    return ListTile(
      leading: Icon(failed ? Icons.error_outline : Icons.downloading, color: failed ? Colors.red : null),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (!failed) LinearProgressIndicator(value: task.total == 0 ? null : task.fraction),
          const SizedBox(height: 4),
          Text(failed ? l.downloadFailed(_describeFailure(task.error, l)) : l.downloadProgress(task.done, task.total)),
        ],
      ),
      trailing: failed
          ? IconButton(tooltip: l.commonRemove, icon: const Icon(Icons.close), onPressed: () => manager.clear(task.novelId))
          : IconButton(tooltip: l.downloadsCancel, icon: const Icon(Icons.stop_circle_outlined), onPressed: () => manager.cancel(task.novelId)),
    );
  }
}

String _describeFailure(Object? error, AppLocalizations l) => switch (error) {
      null => '',
      DownloadNeedsNetwork() => l.downloadNeedsNetwork,
      final e => describeError(e, l),
    };

class _DownloadedTile extends ConsumerWidget {
  final DownloadedNovel novel;

  const _DownloadedTile({required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final chapters = novel.totalChapters > 0
        ? l.downloadsChapterCountOf(novel.downloadedChapters, novel.totalChapters)
        : l.downloadsChapterCount(novel.downloadedChapters);
    final title = novel.title.isEmpty ? l.unknownNovel : novel.title;
    return ListTile(
      leading: NovelCover(url: novel.coverUrl, width: 40, height: 56),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [chapters, formatBytes(novel.sizeBytes), if (novel.isComplete) l.downloadsComplete].join(' · '),
      ),
      onTap: () => context.push('/novel/${novel.novelId}'),
      trailing: IconButton(
        tooltip: l.downloadsDelete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l.downloadsDelete),
              content: Text(l.downloadsDeleteConfirm(title)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.commonDelete)),
              ],
            ),
          );
          if (ok != true) return;
          ref.read(downloadManagerProvider.notifier).cancel(novel.novelId);
          await (await ref.read(offlineStoreProvider)()).deleteDownloadedNovel(novel.novelId);
          ref.read(downloadManagerProvider.notifier).clear(novel.novelId);
          ref.invalidate(downloadedNovelsProvider);
          ref.invalidate(readingCacheSizeProvider);
        },
      ),
    );
  }
}
