import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../data/search_repository.dart';
import '../../../bookstore/domain/entities/novel.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Novel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.read(searchRepositoryProvider);
  final result = await repo.search(query);
  return result.hits;
});

final hotKeywordsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(searchRepositoryProvider);
  return repo.getHotKeywords();
});

/// Recent searches kept in local_search_history.
final searchHistoryProvider = FutureProvider<List<String>>((ref) async {
  try {
    final store = await ref.read(offlineStoreProvider)();
    return await store.recentSearches();
  } catch (_) {
    return const [];
  }
});
