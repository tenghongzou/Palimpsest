import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/novel.dart';
import '../bookstore_labels.dart';
import '../providers/bookstore_provider.dart';
import '../widgets/novel_card.dart';
import '../widgets/novel_carousel.dart';
import '../../../../core/l10n/l10n.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return Scaffold(
      appBar: AppBar(
        // Wide layouts already show the logo at the top of the navigation rail.
        title: isWideLayout(context) ? Text(context.l10n.navHome) : const BrandLogo.horizontal(height: 26),
        actions: [
          IconButton(tooltip: context.l10n.search, icon: const Icon(Icons.search), onPressed: () => context.push('/search')),
          const NotificationBell(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(recommendationsProvider);
          return ref.refresh(homeProvider.future);
        },
        child: home.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text(context.l10n.commonLoadFailed(describeError(e, context.l10n)))),
            const SizedBox(height: 8),
            Center(child: OutlinedButton(onPressed: () => ref.invalidate(homeProvider), child: Text(context.l10n.commonRetry))),
          ]),
          data: (data) => ReadableInset(
            builder: (context, inset) => ListView(
            padding: EdgeInsets.symmetric(horizontal: 16 + inset, vertical: 16),
            children: [
              if (data.banners.isNotEmpty) ...[
                _BannerCarousel(banners: data.banners),
                const SizedBox(height: 16),
              ],
              const _QuickEntries(),
              const SizedBox(height: 16),
              const _Recommendations(),
              ..._section(context, context.l10n.homeFeatured, data.featured, null),
              ..._section(context, context.l10n.homePopular, data.popular, '/ranking/views'),
              ..._section(context, context.l10n.homeLatest, data.latestUpdates, '/ranking/latest'),
              ..._section(context, context.l10n.homeNewArrivals, data.newArrivals, '/novels?sort_by=new'),
              ..._section(context, context.l10n.homeCompleted, data.completed, '/ranking/completed'),
            ],
          ),
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

/// "For you" (or popular picks when not personalized); nothing while it
/// loads, when it is empty or when it fails.
class _Recommendations extends ConsumerWidget {
  const _Recommendations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recommendationsProvider);
    final data = async.hasError ? null : async.valueOrNull;
    // Without personal signals the list is just popular novels, which the
    // home page already shows further down.
    if (data == null || !data.personalized || data.items.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      key: const ValueKey('home-recommendations'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: l.homeRecommended),
        NovelCarousel(
          tiles: [
            for (final item in data.items)
              NovelCoverTile(
                novel: item.novel,
                subtitle: recommendationReasonLabel(item.reason, l),
                onTap: () => context.push('/novel/${item.novel.id}'),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
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
        entry(Icons.leaderboard_outlined, context.l10n.rankings, '/ranking/views'),
        entry(Icons.category_outlined, context.l10n.categories, '/categories'),
        entry(Icons.library_books_outlined, context.l10n.allNovels, '/novels'),
        entry(Icons.task_alt, context.l10n.homeCompletedShort, '/ranking/completed'),
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
      // Mouse drags swipe the banners too (desktop).
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: PageView(
        controller: PageController(viewportFraction: 0.92),
        children: banners
            .map((b) => MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
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
                )))
            .toList(),
        ),
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
            TextButton(onPressed: onMore, child: Text(context.l10n.commonMore)),
        ],
      ),
    );
  }
}
