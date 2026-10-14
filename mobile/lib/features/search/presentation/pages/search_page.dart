import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/network/api_error.dart';
import '../providers/search_provider.dart';
import '../../../bookstore/presentation/widgets/novel_card.dart';
import '../../../../core/l10n/l10n.dart';

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
          decoration: InputDecoration(
            hintText: context.l10n.searchHint,
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: query.isEmpty
          ? _buildHotKeywords(hotKeywords)
          : results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(context.l10n.searchFailed(describeError(e, context.l10n)))),
              data: (novels) {
                if (novels.isEmpty) {
                  return Center(child: Text(context.l10n.searchNoResults));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: novels.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NovelCard(
                      novel: novels[index],
                      onTap: () => context.push('/novel/${novels[index].id}'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _search(String keyword) {
    ref.read(searchQueryProvider.notifier).state = keyword;
    if (keyword.trim().isEmpty) return;
    () async {
      try {
        final store = await ref.read(offlineStoreProvider)();
        await store.addSearchKeyword(keyword);
        ref.invalidate(searchHistoryProvider);
      } catch (_) {
        // History is a convenience; searching works without it.
      }
    }();
  }

  Widget _buildHotKeywords(AsyncValue<List<String>> hotKeywords) {
    final history = ref.watch(searchHistoryProvider).valueOrNull ?? const <String>[];
    return ListView(
      children: [
        if (history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.searchRecent, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        try {
                          final store = await ref.read(offlineStoreProvider)();
                          await store.clearSearchHistory();
                        } catch (_) {}
                        ref.invalidate(searchHistoryProvider);
                      },
                      child: Text(context.l10n.searchClear),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: history.map((k) => ActionChip(
                    avatar: const Icon(Icons.history, size: 16),
                    label: Text(k),
                    onPressed: () {
                      _controller.text = k;
                      _search(k);
                    },
                  )).toList(),
                ),
              ],
            ),
          ),
        _buildHotKeywordList(hotKeywords),
      ],
    );
  }

  Widget _buildHotKeywordList(AsyncValue<List<String>> hotKeywords) {
    return hotKeywords.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (keywords) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.searchHot, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.map((k) => ActionChip(
                label: Text(k),
                onPressed: () {
                  _controller.text = k;
                  _search(k);
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
