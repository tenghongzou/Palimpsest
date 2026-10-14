import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../data/novel_repository.dart';
import '../../domain/entities/novel.dart';
import '../providers/bookstore_provider.dart';
import '../bookstore_labels.dart';
import '../widgets/novel_card.dart';
import '../../../../core/l10n/l10n.dart';

/// Rankings by type (tabs) and period.
class RankingPage extends StatefulWidget {
  final String type;
  final String period;

  const RankingPage({super.key, required this.type, this.period = 'weekly'});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> with SingleTickerProviderStateMixin {
  late final List<String> _types = rankingTypes;
  late final TabController _tabs = TabController(
    length: _types.length,
    vsync: this,
    initialIndex: _types.contains(widget.type) ? _types.indexOf(widget.type) : 0,
  );
  late String _period = rankingPeriods.contains(widget.period) ? widget.period : 'weekly';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.rankings),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: _types.map((t) => Tab(text: rankingTypeLabel(t, l))).toList(),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: rankingPeriods
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(rankingPeriodLabel(e, l)),
                          selected: _period == e,
                          onSelected: (_) => setState(() => _period = e),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: _types.map((t) => _RankingList(params: RankingParams(type: t, period: _period))).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingList extends ConsumerWidget {
  final RankingParams params;

  const _RankingList({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rankingProvider(params));
    final notifier = ref.read(rankingProvider(params).notifier);
    return PagedListView<Novel>(
      state: state,
      onLoadMore: notifier.loadMore,
      onRefresh: notifier.refresh,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      empty: Text(context.l10n.rankingEmpty),
      itemBuilder: (context, novel, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${i + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: i < 3 ? Colors.orange.shade700 : Colors.grey,
                ),
              ),
            ),
            Expanded(child: NovelCard(novel: novel, onTap: () => context.push('/novel/${novel.id}'))),
          ],
        ),
      ),
    );
  }
}
