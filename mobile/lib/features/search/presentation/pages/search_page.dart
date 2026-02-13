import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/search_provider.dart';
import '../../../bookstore/presentation/widgets/novel_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final hotKeywords = ref.watch(hotKeywordsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜尋小說名稱、作者...',
            border: InputBorder.none,
          ),
          onSubmitted: (v) => ref.read(searchQueryProvider.notifier).state = v,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => ref.read(searchQueryProvider.notifier).state = _controller.text,
          ),
        ],
      ),
      body: query.isEmpty
          ? _buildHotKeywords(hotKeywords)
          : results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('搜尋失敗：$e')),
              data: (novels) {
                if (novels.isEmpty) {
                  return const Center(child: Text('沒有找到相關小說'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: novels.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NovelCard(
                      novel: novels[index],
                      onTap: () => context.go('/novel/${novels[index].id}'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHotKeywords(AsyncValue<List<String>> hotKeywords) {
    return hotKeywords.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (keywords) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('熱門搜尋', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.map((k) => ActionChip(
                label: Text(k),
                onPressed: () {
                  _controller.text = k;
                  ref.read(searchQueryProvider.notifier).state = k;
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
