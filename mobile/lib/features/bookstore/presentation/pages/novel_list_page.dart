import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../data/novel_repository.dart';
import '../../domain/entities/novel.dart';
import '../bookstore_labels.dart';
import '../providers/bookstore_provider.dart';
import '../widgets/novel_card.dart';
import '../../../../core/l10n/l10n.dart';

const _statusOptions = <String?>[null, 'ongoing', 'completed', 'hiatus'];

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
    sortBy: novelSortOptions.contains(widget.sortBy) ? widget.sortBy! : 'latest',
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(novelListProvider(_query));
    final notifier = ref.read(novelListProvider(_query).notifier);
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? (widget.category == null ? l.allNovels : l.novelListCategory))),
      body: Column(
        children: [
          _chips(novelSortOptions, (v) => novelSortLabel(v, l), _query.sortBy, (v) => _query.copyWith(sortBy: v)),
          _chips(_statusOptions, (v) => novelStatusLabel(v, l), _query.status,
              (v) => _query.copyWith(status: v, clearStatus: v == null)),
          const Divider(height: 1),
          Expanded(
            child: PagedListView<Novel>(
              state: state,
              onLoadMore: notifier.loadMore,
              onRefresh: notifier.refresh,
              padding: const EdgeInsets.all(16),
              empty: Text(l.novelListEmpty),
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

  Widget _chips<T>(List<T> options, String Function(T) label, T selected, NovelQuery Function(T) apply) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: options
            .map((e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label(e)),
                    selected: selected == e,
                    onSelected: (_) => setState(() => _query = apply(e)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
