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
import '../widgets/novel_carousel.dart';
import '../../../../core/l10n/l10n.dart';

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
      showSnack(context, context.l10n.errorUnauthorized);
      context.push('/login');
      return;
    }
    setState(() => _adding = true);
    try {
      await ref.read(bookshelfProvider.notifier).add(novelId);
      if (mounted) showSnack(context, context.l10n.novelAddedToShelf);
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.novelAddToShelfFailed(describeError(e, context.l10n)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final novelAsync = ref.watch(novelDetailProvider(novelId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.novelDetailTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.l10n.commonMore,
            onSelected: (_) {
              if (ref.read(authStateProvider).valueOrNull == null) {
                showSnack(context, context.l10n.errorUnauthorized);
                return;
              }
              showReportDialog(context, ref, targetType: 'novel', targetId: novelId);
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(context.l10n.novelReport))],
          ),
        ],
      ),
      body: novelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.commonLoadFailed(describeError(e, context.l10n)))),
        data: (novel) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(novelDetailProvider(novelId));
            ref.invalidate(chapterListProvider(novelId));
            ref.invalidate(reviewsProvider(novelId));
            ref.invalidate(similarNovelsProvider(novelId));
          },
          child: ReadableInset(
            builder: (context, inset) => ListView(
            padding: EdgeInsets.symmetric(horizontal: 16 + inset, vertical: 16),
            children: [
              _buildHeader(novel),
              const SizedBox(height: 16),
              _buildActions(novel),
              _buildDownload(novel),
              const SizedBox(height: 16),
              Text(context.l10n.novelSynopsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(novel.description ?? context.l10n.novelNoSynopsis, style: TextStyle(color: Colors.grey.shade700, height: 1.6)),
              const SizedBox(height: 24),
              _buildSimilar(),
              _buildChapters(),
              const SizedBox(height: 24),
              ReviewSection(novelId: novelId),
            ],
          ),
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
                Text(context.l10n.novelChaptersAndWords(novel.totalChapters, formatWordCount(novel.totalWords, context.l10n)),
                    style: TextStyle(color: Colors.grey.shade600)),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...novel.categories.map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 12)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                  // A tag named like one of the categories would only repeat it.
                  ...novel.tags.where((t) => !novel.categories.contains(t)).map((t) => Chip(label: Text(t, style: const TextStyle(fontSize: 12)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
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
            child: Text(resume != null ? context.l10n.novelContinueReading : context.l10n.novelStartReading),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onShelf || _adding ? null : _addToBookshelf,
            child: Text(onShelf ? context.l10n.novelOnShelf : (_adding ? context.l10n.novelAdding : context.l10n.novelAddToShelf)),
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
                  Text(context.l10n.downloadProgress(task.done, task.total), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            TextButton(onPressed: () => manager.cancel(novelId), child: Text(context.l10n.commonCancel)),
          ],
        ),
      );
    }
    final label = switch (task?.status) {
      DownloadStatus.completed => context.l10n.downloadDone,
      DownloadStatus.failed => context.l10n.downloadFailedRetry,
      _ => context.l10n.downloadAll,
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

  /// Similar novels; nothing while loading, when empty or on failure.
  Widget _buildSimilar() {
    final async = ref.watch(similarNovelsProvider(novelId));
    final novels = async.hasError ? null : async.valueOrNull;
    if (novels == null || novels.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('novel-similar'),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.novelSimilar,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          NovelCarousel(
            tiles: [
              for (final novel in novels)
                NovelCoverTile(
                  novel: novel,
                  subtitle: novel.authorName,
                  onTap: () => context.push('/novel/${novel.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapters() {
    final chaptersAsync = ref.watch(chapterListProvider(novelId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.novelChapterList, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        chaptersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(context.l10n.novelChaptersLoadFailed(describeError(e, context.l10n))),
          data: (chapters) {
            const preview = 20;
            final shown = _showAllChapters ? chapters : chapters.take(preview).toList();
            return Column(
              children: [
                ...shown.map((ch) => ListTile(
                      title: Text(chapterLabel(ch.chapterNumber, ch.title, context.l10n), style: const TextStyle(fontSize: 14)),
                      trailing: Text(context.l10n.wordCount(formatNumber(ch.wordCount, context.l10n)), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      dense: true,
                      onTap: () => _read('/read/${ch.id}'),
                    )),
                if (chapters.length > preview && !_showAllChapters)
                  TextButton(
                    onPressed: () => setState(() => _showAllChapters = true),
                    child: Text(context.l10n.novelShowAllChapters(chapters.length)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
