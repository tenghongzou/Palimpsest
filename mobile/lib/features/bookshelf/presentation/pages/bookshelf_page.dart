import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/bookshelf_provider.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(bookshelfProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final bookshelf = ref.watch(bookshelfProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的書架')),
      body: bookshelf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('書架還是空的'),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: () => context.go('/'), child: const Text('去逛逛')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(bookshelfProvider.notifier).load(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red, alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => ref.read(bookshelfProvider.notifier).remove(item.novelId),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: item.coverUrl != null
                          ? CachedNetworkImage(imageUrl: item.coverUrl!, width: 40, height: 56, fit: BoxFit.cover)
                          : Container(width: 40, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.book, size: 20)),
                    ),
                    title: Text(item.novelTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: item.progress != null
                        ? Text('讀到 第${item.progress!.chapterNumber}章', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                        : null,
                    trailing: item.hasUpdate
                        ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                        : null,
                    onTap: () => context.go('/novel/${item.novelId}'),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/');
            case 1: break;
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
