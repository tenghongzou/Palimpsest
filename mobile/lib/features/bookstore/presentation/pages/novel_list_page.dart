import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../data/novel_repository.dart';
import '../../domain/entities/novel.dart';
import '../providers/bookstore_provider.dart';
import '../widgets/novel_card.dart';

const _statusOptions = <String?, String>{null: '全部', 'ongoing': '連載中', 'completed': '已完結', 'hiatus': '暫停'};

/// Novels filtered by category (slug), status and sort order (GET /novels).
class NovelListPage extends ConsumerStatefulWidget {
  final String? category;
  final String? title;
  final String? sortBy;

  const NovelListPage({super.key, this.category, this.title, this.sortBy});

  @override
  ConsumerState<NovelListPage> createState() => _NovelListPageState();
}

class _NovelListPageState extends ConsumerState<NovelListPage> {
  late NovelQuery _query = NovelQuery(
    category: widget.category,
    sortBy: novelSortOptions.containsKey(widget.sortBy) ? widget.sortBy! : 'latest',
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(novelListProvider(_query));
    final notifier = ref.read(novelListProvider(_query).notifier);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? (widget.category == null ? '全部作品' : '分類作品'))),
      body: Column(
        children: [
          _chips(novelSortOptions, _query.sortBy, (v) => _query.copyWith(sortBy: v)),
          _chips(_statusOptions, _query.status, (v) => _query.copyWith(status: v, clearStatus: v == null)),
          const Divider(height: 1),
          Expanded(
            child: PagedListView<Novel>(
              state: state,
              onLoadMore: notifier.loadMore,
              onRefresh: notifier.refresh,
              padding: const EdgeInsets.all(16),
              empty: const Text('沒有符合條件的作品'),
              itemBuilder: (context, novel, _) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NovelCard(novel: novel, onTap: () => context.push('/novel/${novel.id}')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips<T>(Map<T, String> options, T selected, NovelQuery Function(T) apply) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: options.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected == e.key,
                    onSelected: (_) => setState(() => _query = apply(e.key)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
