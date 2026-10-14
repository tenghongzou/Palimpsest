import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../bookshelf/presentation/providers/bookshelf_provider.dart';
import '../../../community/presentation/widgets/report_dialog.dart';
import '../../../community/presentation/widgets/review_section.dart';
import '../../../downloads/data/download_manager.dart';
import '../../../reader/presentation/providers/progress_provider.dart';
import '../../domain/entities/novel.dart';
import '../providers/bookstore_provider.dart';

class NovelDetailPage extends ConsumerStatefulWidget {
  final String novelId;

  const NovelDetailPage({super.key, required this.novelId});

  @override
  ConsumerState<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends ConsumerState<NovelDetailPage> {
  bool _adding = false;
  bool _showAllChapters = false;

  String get novelId => widget.novelId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final bookshelf = ref.read(bookshelfProvider);
      if (ref.read(authStateProvider).valueOrNull != null && !bookshelf.hasValue) {
        ref.read(bookshelfProvider.notifier).load();
      }
    });
  }

  Future<void> _read(String location) async {
    await context.push(location);
    // Reading moved the saved position.
    if (mounted) ref.invalidate(resumePointProvider(novelId));
  }

  Future<void> _addToBookshelf() async {
    if (ref.read(authStateProvider).valueOrNull == null) {
      showSnack(context, '請先登入');
      context.push('/login');
      return;
    }
    setState(() => _adding = true);
    try {
      await ref.read(bookshelfProvider.notifier).add(novelId);
      if (mounted) showSnack(context, '已加入書架');
    } catch (e) {
      if (mounted) showSnack(context, '加入書架失敗：${describeError(e)}');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final novelAsync = ref.watch(novelDetailProvider(novelId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('小說詳情'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (_) {
              if (ref.read(authStateProvider).valueOrNull == null) {
                showSnack(context, '請先登入');
                return;
              }
              showReportDialog(context, ref, targetType: 'novel', targetId: novelId);
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('檢舉作品'))],
          ),
        ],
      ),
      body: novelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：${describeError(e)}')),
        data: (novel) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(novelDetailProvider(novelId));
            ref.invalidate(chapterListProvider(novelId));
            ref.invalidate(reviewsProvider(novelId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(novel),
              const SizedBox(height: 16),
              _buildActions(novel),
              _buildDownload(novel),
              const SizedBox(height: 16),
              Text('簡介', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(novel.description ?? '暫無簡介', style: TextStyle(color: Colors.grey.shade700, height: 1.6)),
              const SizedBox(height: 24),
              _buildChapters(),
              const SizedBox(height: 24),
              ReviewSection(novelId: novelId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Novel novel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NovelCover(url: novel.coverUrl, width: 120, height: 168),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(novel.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(novel.authorName, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(novel.avgRating.toStringAsFixed(1)),
                const SizedBox(width: 16),
                Text('${novel.totalChapters}章 · ${formatWordCount(novel.totalWords)}', style: TextStyle(color: Colors.grey.shade600)),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...novel.categories.map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 12)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                  ...novel.tags.map((t) => Chip(label: Text(t, style: const TextStyle(fontSize: 12)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Novel novel) {
    final chapters = ref.watch(chapterListProvider(novelId)).valueOrNull;
    final resume = ref.watch(resumePointProvider(novelId)).valueOrNull;
    ref.watch(bookshelfProvider);
    final onShelf = ref.read(bookshelfProvider.notifier).contains(novelId);

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: resume != null
                ? () => _read(resume.location)
                : (chapters == null || chapters.isEmpty ? null : () => _read('/read/${chapters.first.id}')),
            child: Text(resume != null ? '繼續閱讀' : '開始閱讀'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onShelf || _adding ? null : _addToBookshelf,
            child: Text(onShelf ? '已在書架' : (_adding ? '加入中…' : '加入書架')),
          ),
        ),
      ],
    );
  }

  Widget _buildDownload(Novel novel) {
    final task = ref.watch(downloadManagerProvider)[novelId];
    final manager = ref.read(downloadManagerProvider.notifier);
    if (task != null && task.isActive) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: task.total == 0 ? null : task.fraction),
                  const SizedBox(height: 4),
                  Text('下載中 ${task.done}/${task.total} 章', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            TextButton(onPressed: () => manager.cancel(novelId), child: const Text('取消')),
          ],
        ),
      );
    }
    final label = switch (task?.status) {
      DownloadStatus.completed => '已下載全部章節',
      DownloadStatus.failed => '下載失敗，點此重試',
      _ => '下載全部章節（離線閱讀）',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: Icon(task?.status == DownloadStatus.completed ? Icons.download_done : Icons.download_outlined),
        label: Text(label),
        onPressed: () => manager.download(novel),
      ),
    );
  }

  Widget _buildChapters() {
    final chaptersAsync = ref.watch(chapterListProvider(novelId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('章節列表', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        chaptersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('載入章節失敗：${describeError(e)}'),
          data: (chapters) {
            const preview = 20;
            final shown = _showAllChapters ? chapters : chapters.take(preview).toList();
            return Column(
              children: [
                ...shown.map((ch) => ListTile(
                      title: Text('第${ch.chapterNumber}章 ${ch.title}', style: const TextStyle(fontSize: 14)),
                      trailing: Text('${ch.wordCount}字', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      dense: true,
                      onTap: () => _read('/read/${ch.id}'),
                    )),
                if (chapters.length > preview && !_showAllChapters)
                  TextButton(
                    onPressed: () => setState(() => _showAllChapters = true),
                    child: Text('顯示全部 ${chapters.length} 章'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
