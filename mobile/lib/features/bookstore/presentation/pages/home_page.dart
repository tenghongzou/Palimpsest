import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/novel.dart';
import '../providers/bookstore_provider.dart';
import '../widgets/novel_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Palimpsest'),
        actions: [
          IconButton(tooltip: '搜尋', icon: const Icon(Icons.search), onPressed: () => context.push('/search')),
          const NotificationBell(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeProvider.future),
        child: home.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('載入失敗：${describeError(e)}')),
            const SizedBox(height: 8),
            Center(child: OutlinedButton(onPressed: () => ref.invalidate(homeProvider), child: const Text('重試'))),
          ]),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.banners.isNotEmpty) ...[
                _BannerCarousel(banners: data.banners),
                const SizedBox(height: 16),
              ],
              const _QuickEntries(),
              const SizedBox(height: 16),
              ..._section(context, '編輯推薦', data.featured, null),
              ..._section(context, '熱門推薦', data.popular, '/ranking/views'),
              ..._section(context, '最新更新', data.latestUpdates, '/ranking/latest'),
              ..._section(context, '新書上架', data.newArrivals, '/novels?sort_by=new'),
              ..._section(context, '完本精選', data.completed, '/ranking/completed'),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 0),
    );
  }

  List<Widget> _section(BuildContext context, String title, List<Novel> novels, String? more) {
    if (novels.isEmpty) return const [];
    return [
      _SectionHeader(title: title, onMore: more == null ? null : () => context.push(more)),
      ...novels.map((novel) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NovelCard(novel: novel, onTap: () => context.push('/novel/${novel.id}')),
          )),
      const SizedBox(height: 16),
    ];
  }
}

class _QuickEntries extends StatelessWidget {
  const _QuickEntries();

  @override
  Widget build(BuildContext context) {
    Widget entry(IconData icon, String label, String path) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push(path),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        );
    return Row(
      children: [
        entry(Icons.leaderboard_outlined, '排行榜', '/ranking/views'),
        entry(Icons.category_outlined, '分類', '/categories'),
        entry(Icons.library_books_outlined, '全部作品', '/novels'),
        entry(Icons.task_alt, '完本', '/ranking/completed'),
      ],
    );
  }
}

class _BannerCarousel extends StatelessWidget {
  final List<HomeBanner> banners;

  const _BannerCarousel({required this.banners});

  void _open(BuildContext context, HomeBanner b) {
    final value = b.linkValue;
    if (value == null || value.isEmpty) return;
    switch (b.linkType) {
      case 'novel':
        context.push('/novel/$value');
      case 'category':
        context.push('/novels?category=${Uri.encodeQueryComponent(value)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: PageView(
        controller: PageController(viewportFraction: 0.92),
        children: banners
            .map((b) => GestureDetector(
                  onTap: () => _open(context, b),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: b.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(color: Colors.grey.shade300),
                            placeholder: (_, __) => Container(color: Colors.grey.shade200),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              width: double.infinity,
                              color: Colors.black38,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Text(b.title, style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;

  const _SectionHeader({required this.title, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (onMore != null)
            TextButton(onPressed: onMore, child: const Text('更多')),
        ],
      ),
    );
  }
}
