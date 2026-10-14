import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../data/novel_repository.dart';
import '../providers/bookstore_provider.dart';
import '../../../../core/l10n/l10n.dart';

class CategoryListPage extends ConsumerWidget {
  const CategoryListPage({super.key});

  static String novelsLocation(CategoryItem c) =>
      '/novels?category=${Uri.encodeQueryComponent(c.slug)}&title=${Uri.encodeQueryComponent(c.name)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.categories)),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.commonLoadFailed(describeError(e, context.l10n)))),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(categoriesProvider.future),
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = list[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(novelsLocation(c)),
                    ),
                    if (c.children.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: c.children
                              .map((child) => ActionChip(
                                    label: Text(child.name),
                                    onPressed: () => context.push(novelsLocation(child)),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
