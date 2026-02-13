import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/bookstore_provider.dart';
import '../../../bookshelf/presentation/providers/bookshelf_provider.dart';

class NovelDetailPage extends ConsumerWidget {
  final String novelId;

  const NovelDetailPage({super.key, required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelAsync = ref.watch(novelDetailProvider(novelId));
    final chaptersAsync = ref.watch(chapterListProvider(novelId));

    return Scaffold(
      appBar: AppBar(title: const Text('小說詳情')),
      body: novelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
        data: (novel) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: novel.coverUrl != null
                      ? CachedNetworkImage(imageUrl: novel.coverUrl!, width: 120, height: 168, fit: BoxFit.cover)
                      : Container(width: 120, height: 168, color: Colors.grey.shade200, child: const Icon(Icons.book, size: 40)),
                ),
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
                        Text('${novel.totalChapters}章', style: TextStyle(color: Colors.grey.shade600)),
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
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      chaptersAsync.whenData((chapters) {
                        if (chapters.isNotEmpty) context.go('/read/${chapters.first.id}');
                      });
                    },
                    child: const Text('開始閱讀'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(bookshelfProvider.notifier).add(novelId);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入書架')));
                    },
                    child: const Text('加入書架'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('簡介', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(novel.description ?? '暫無簡介', style: TextStyle(color: Colors.grey.shade700, height: 1.6)),
            const SizedBox(height: 24),
            Text('章節列表', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            chaptersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('載入章節失敗：$e'),
              data: (chapters) => Column(
                children: chapters.map((ch) => ListTile(
                  title: Text('第${ch.chapterNumber}章 ${ch.title}', style: const TextStyle(fontSize: 14)),
                  trailing: Text('${ch.wordCount}字', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  dense: true,
                  onTap: () => context.go('/read/${ch.id}'),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
