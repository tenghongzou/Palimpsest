import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/novel.dart';

final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  return NovelRepository(ref.read(apiClientProvider));
});

class NovelRepository {
  final ApiClient _apiClient;

  NovelRepository(this._apiClient);

  Future<PaginatedNovels> getNovelList({
    int page = 1,
    int pageSize = 20,
    String? sort,
    String? status,
    String? category,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (sort != null) params['sort'] = sort;
    if (status != null) params['status'] = status;
    if (category != null) params['category'] = category;

    final response = await _apiClient.dio.get('/novels', queryParameters: params);
    final data = response.data['data'];
    final items = (data['items'] as List).map((e) => _parseNovel(e)).toList();
    final pagination = data['pagination'];

    return PaginatedNovels(
      items: items,
      page: pagination['page'] as int,
      totalPages: pagination['total_pages'] as int,
      total: pagination['total'] as int,
    );
  }

  Future<Novel> getNovelById(String id) async {
    final response = await _apiClient.dio.get('/novels/$id');
    return _parseNovel(response.data['data']);
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
    return (response.data['data'] as List).map((e) => CategoryItem(
      id: e['id'] as int,
      name: e['name'] as String,
      slug: e['slug'] as String,
    )).toList();
  }

  Future<PaginatedNovels> getRanking(String type, {String period = 'weekly', int page = 1}) async {
    final response = await _apiClient.dio.get(
      '/rankings/$type',
      queryParameters: {'period': period, 'page': page},
    );
    final data = response.data['data'];
    final items = (data['items'] as List).map((e) => _parseNovel(e)).toList();
    return PaginatedNovels(items: items, page: page, totalPages: 1, total: items.length);
  }

  Novel _parseNovel(Map<String, dynamic> json) {
    return Novel(
      id: json['id'] as String,
      title: json['title'] as String,
      authorName: json['author_name'] as String,
      coverUrl: json['cover_url'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'ongoing',
      language: json['language'] as String? ?? 'zh-TW',
      totalWords: json['total_words'] as int? ?? 0,
      totalChapters: json['total_chapters'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      latestChapterTitle: json['latest_chapter_title'] as String?,
      latestChapterAt: json['latest_chapter_at'] != null
          ? DateTime.tryParse(json['latest_chapter_at'] as String)
          : null,
      categories: (json['categories'] as List?)?.map((c) => c['name'] as String).toList() ?? [],
      tags: (json['tags'] as List?)?.map((t) => t['name'] as String).toList() ?? [],
    );
  }
}

class PaginatedNovels {
  final List<Novel> items;
  final int page;
  final int totalPages;
  final int total;

  const PaginatedNovels({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
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
  final String name;
  final String slug;

  const CategoryItem({required this.id, required this.name, required this.slug});
}
