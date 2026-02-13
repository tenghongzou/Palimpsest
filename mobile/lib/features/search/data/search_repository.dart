import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../bookstore/domain/entities/novel.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.read(apiClientProvider));
});

class SearchRepository {
  final ApiClient _apiClient;

  SearchRepository(this._apiClient);

  Future<SearchResult> search(String query, {int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.dio.get('/search', queryParameters: {
      'q': query,
      'page': page,
      'page_size': pageSize,
    });
    final data = response.data['data'];
    final hits = (data['hits'] as List).map((e) => _parseNovel(e)).toList();
    return SearchResult(
      hits: hits,
      total: data['total'] as int? ?? hits.length,
    );
  }

  Future<List<String>> getHotKeywords() async {
    final response = await _apiClient.dio.get('/search/hot');
    return (response.data['data'] as List).cast<String>();
  }

  Future<List<String>> getSuggestions(String query) async {
    final response = await _apiClient.dio.get('/search/suggestions', queryParameters: {'q': query});
    return (response.data['data'] as List).cast<String>();
  }

  Novel _parseNovel(Map<String, dynamic> json) {
    return Novel(
      id: json['id'] as String,
      title: json['title'] as String,
      authorName: json['author_name'] as String,
      coverUrl: json['cover_url'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'ongoing',
      totalWords: json['total_words'] as int? ?? 0,
      totalChapters: json['total_chapters'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SearchResult {
  final List<Novel> hits;
  final int total;

  const SearchResult({required this.hits, required this.total});
}
