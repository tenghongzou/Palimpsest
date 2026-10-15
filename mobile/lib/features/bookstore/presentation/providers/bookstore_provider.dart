import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/novel_repository.dart';
import '../../domain/entities/home_data.dart';
import '../../domain/entities/novel.dart';
import '../../domain/entities/recommendation.dart';

final homeProvider = FutureProvider<HomeData>((ref) async {
  return ref.read(novelRepositoryProvider).getHome();
});

/// The home page's "for you" list. Fetched again when the signed-in account
/// changes (signing in or out changes what the server recommends).
final recommendationsProvider = FutureProvider<Recommendations>((ref) async {
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.id));
  return ref.read(novelRepositoryProvider).getRecommendations();
});

/// Novels similar to a novel, for its detail page.
final similarNovelsProvider = FutureProvider.autoDispose.family<List<Novel>, String>((ref, novelId) async {
  return ref.read(novelRepositoryProvider).getSimilarNovels(novelId);
});

final novelDetailProvider = FutureProvider.family<Novel, String>((ref, id) async {
  final repo = ref.read(novelRepositoryProvider);
  return repo.getNovelById(id);
});

final chapterListProvider = FutureProvider.family<List<ChapterInfo>, String>((ref, novelId) async {
  final repo = ref.read(novelRepositoryProvider);
  return repo.getChapters(novelId);
});

final categoriesProvider = FutureProvider<List<CategoryItem>>((ref) async {
  final repo = ref.read(novelRepositoryProvider);
  return repo.getCategories();
});

final rankingProvider = StateNotifierProvider.autoDispose
    .family<PagedNotifier<Novel>, PagedState<Novel>, RankingParams>((ref, params) {
  final repo = ref.read(novelRepositoryProvider);
  return PagedNotifier((page) => repo.getRanking(params.type, period: params.period, page: page));
});

final novelListProvider = StateNotifierProvider.autoDispose
    .family<PagedNotifier<Novel>, PagedState<Novel>, NovelQuery>((ref, query) {
  final repo = ref.read(novelRepositoryProvider);
  return PagedNotifier((page) => repo.getNovelList(
        page: page,
        sortBy: query.sortBy,
        status: query.status,
        category: query.category,
      ));
});

class RankingParams {
  final String type;
  final String period;

  const RankingParams({required this.type, this.period = 'weekly'});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RankingParams && type == other.type && period == other.period;

  @override
  int get hashCode => Object.hash(type, period);
}

/// Filters of GET /novels.
class NovelQuery {
  final String sortBy;
  final String? status;

  /// Category slug.
  final String? category;

  const NovelQuery({this.sortBy = 'latest', this.status, this.category});

  NovelQuery copyWith({String? sortBy, String? status, bool clearStatus = false}) => NovelQuery(
        sortBy: sortBy ?? this.sortBy,
        status: clearStatus ? null : status ?? this.status,
        category: category,
      );

  @override
  bool operator ==(Object other) =>
      other is NovelQuery && other.sortBy == sortBy && other.status == status && other.category == category;

  @override
  int get hashCode => Object.hash(sortBy, status, category);
}
