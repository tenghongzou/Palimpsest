import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/novel_repository.dart';
import '../../domain/entities/novel.dart';

final homeNovelsProvider = FutureProvider.family<List<Novel>, String>((ref, sort) async {
  final repo = ref.read(novelRepositoryProvider);
  final result = await repo.getNovelList(sort: sort, pageSize: 6);
  return result.items;
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

final rankingProvider = FutureProvider.family<List<Novel>, RankingParams>((ref, params) async {
  final repo = ref.read(novelRepositoryProvider);
  final result = await repo.getRanking(params.type, period: params.period);
  return result.items;
});

class RankingParams {
  final String type;
  final String period;

  const RankingParams({required this.type, this.period = 'weekly'});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RankingParams && type == other.type && period == other.period;

  @override
  int get hashCode => type.hashCode ^ period.hashCode;
}
