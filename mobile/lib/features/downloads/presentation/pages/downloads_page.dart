import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/offline_store.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/download_manager.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('離線下載')),
      body: downloaded.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('讀取下載內容失敗：$e')),
        data: (novels) {
          final totalBytes = novels.fold<int>(0, (sum, n) => sum + n.sizeBytes);
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text('已下載 ${novels.length} 本，共 ${formatBytes(totalBytes)}'),
                subtitle: cacheSize == null ? null : Text('閱讀快取 ${formatBytes(cacheSize)}'),
                trailing: TextButton(
                  onPressed: cacheSize == null || cacheSize == 0
                      ? null
                      : () async {
                          await (await ref.read(offlineStoreProvider)()).clearCachedChapters();
                          ref.invalidate(readingCacheSizeProvider);
                          if (context.mounted) showSnack(context, '已清除閱讀快取');
                        },
                  child: const Text('清除快取'),
                ),
              ),
              const Divider(height: 1),
              ...tasks.map((t) => _TaskTile(task: t)),
              if (novels.isEmpty && tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: EmptyState(icon: Icons.download_outlined, message: '尚未下載任何小說\n在小說詳情頁點選「下載」即可離線閱讀'),
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
    return ListTile(
      leading: Icon(failed ? Icons.error_outline : Icons.downloading, color: failed ? Colors.red : null),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (!failed) LinearProgressIndicator(value: task.total == 0 ? null : task.fraction),
          const SizedBox(height: 4),
          Text(failed ? '下載失敗：${task.error ?? ''}' : '下載中 ${task.done}/${task.total} 章'),
        ],
      ),
      trailing: failed
          ? IconButton(tooltip: '移除', icon: const Icon(Icons.close), onPressed: () => manager.clear(task.novelId))
          : IconButton(tooltip: '取消下載', icon: const Icon(Icons.stop_circle_outlined), onPressed: () => manager.cancel(task.novelId)),
    );
  }
}

class _DownloadedTile extends ConsumerWidget {
  final DownloadedNovel novel;

  const _DownloadedTile({required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = novel.totalChapters > 0 ? '/${novel.totalChapters}' : '';
    return ListTile(
      leading: NovelCover(url: novel.coverUrl, width: 40, height: 56),
      title: Text(novel.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${novel.downloadedChapters}$total 章 · ${formatBytes(novel.sizeBytes)}${novel.isComplete ? ' · 已完整下載' : ''}',
      ),
      onTap: () => context.push('/novel/${novel.novelId}'),
      trailing: IconButton(
        tooltip: '刪除下載',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('刪除下載'),
              content: Text('確定要刪除《${novel.title}》的離線內容嗎？'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
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
