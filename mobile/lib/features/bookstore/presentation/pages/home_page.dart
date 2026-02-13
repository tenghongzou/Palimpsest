import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/bookstore_provider.dart';
import '../widgets/novel_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Palimpsest'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => context.go('/search')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeNovelsProvider('views'));
          ref.invalidate(homeNovelsProvider('latest'));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(title: '熱門推薦', onMore: () => context.go('/ranking/views')),
            _NovelSection(sort: 'views'),
            const SizedBox(height: 24),
            _SectionHeader(title: '最新更新', onMore: () => context.go('/ranking/latest')),
            _NovelSection(sort: 'latest'),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: break;
            case 1: context.go('/bookshelf');
            case 2: context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首頁'),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: '書架'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
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

class _NovelSection extends ConsumerWidget {
  final String sort;

  const _NovelSection({required this.sort});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novels = ref.watch(homeNovelsProvider(sort));

    return novels.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('載入失敗：$e'),
      data: (list) => Column(
        children: list.map((novel) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NovelCard(
            novel: novel,
            onTap: () => context.go('/novel/${novel.id}'),
          ),
        )).toList(),
      ),
    );
  }
}
