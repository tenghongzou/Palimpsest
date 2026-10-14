import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../domain/entities/home_data.dart';
import '../domain/entities/novel.dart';

final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  return NovelRepository(ref.read(apiClientProvider));
});

typedef PaginatedNovels = Paginated<Novel>;

/// `sort_by` values of GET /novels with their labels.
const novelSortOptions = <String, String>{
  'latest': '最近更新',
  'popular': '人氣',
  'rating': '評分',
  'words': '字數',
  'favorites': '收藏',
  'new': '新書',
};

/// Ranking types of GET /rankings/{type} with their labels.
const rankingTypes = <String, String>{
  'views': '人氣榜',
  'favorites': '收藏榜',
  'rating': '評分榜',
  'latest': '更新榜',
  'completed': '完本榜',
};

const rankingPeriods = <String, String>{
  'daily': '日榜',
  'weekly': '週榜',
  'monthly': '月榜',
  'all': '總榜',
};

class NovelRepository {
  final ApiClient _apiClient;

  NovelRepository(this._apiClient);

  /// GET /novels. [sortBy] is one of [novelSortOptions]; [category] is a
  /// category slug and is ignored by the server when [categoryId] is given.
  Future<PaginatedNovels> getNovelList({
    int page = 1,
    int pageSize = 20,
    String? sortBy,
    String? status,
    String? category,
    int? categoryId,
    String? language,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (sortBy != null) 'sort_by': sortBy,
      if (status != null) 'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (category != null) 'category': category,
      if (language != null) 'language': language,
    };
    final response = await _apiClient.dio.get('/novels', queryParameters: params);
    return Paginated.fromJson(response.data['data'] as Map<String, dynamic>, Novel.fromJson);
  }

  Future<HomeData> getHome() async {
    final response = await _apiClient.dio.get('/home');
    return HomeData.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Novel> getNovelById(String id) async {
    final response = await _apiClient.dio.get('/novels/$id');
    return Novel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<ChapterInfo>> getChapters(String novelId, {String order = 'asc'}) async {
    final response = await _apiClient.dio.get(
      '/novels/$novelId/chapters',
      queryParameters: {'order': order},
    );
    return (response.data['data'] as List).map((e) => ChapterInfo(
      id: e['id'] as String,
      title: e['title'] as String,
      chapterNumber: e['chapter_number'] as int,
      wordCount: e['word_count'] as int? ?? 0,
    )).toList();
  }

  Future<List<CategoryItem>> getCategories() async {
    final response = await _apiClient.dio.get('/categories');
    return (response.data['data'] as List)
        .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaginatedNovels> getRanking(String type, {String period = 'weekly', int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.dio.get(
      '/rankings/$type',
      queryParameters: {'period': period, 'page': page, 'page_size': pageSize},
    );
    return Paginated.fromJson(response.data['data'] as Map<String, dynamic>, Novel.fromJson);
  }
}

class ChapterInfo {
  final String id;
  final String title;
  final int chapterNumber;
  final int wordCount;

  const ChapterInfo({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.wordCount,
  });
}

class CategoryItem {
  final int id;
  final int? parentId;
  final String name;
  final String slug;
  final List<CategoryItem> children;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.children = const [],
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
        id: json['id'] as int,
        parentId: json['parent_id'] as int?,
        name: json['name'] as String,
        slug: json['slug'] as String,
        children: (json['children'] as List? ?? const [])
            .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
