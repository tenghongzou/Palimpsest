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
    final response = await _apiClient.dio.get('/search/novels', queryParameters: {
      'q': query,
      'page': page,
      'page_size': pageSize,
    });
    final data = response.data['data'];
    final hits = (data['hits'] as List).map((e) => Novel.fromJson(e as Map<String, dynamic>)).toList();
    return SearchResult(
      hits: hits,
      total: data['estimated_total'] as int? ?? hits.length,
    );
  }

  Future<List<String>> getHotKeywords() async {
    final response = await _apiClient.dio.get('/search/hot-keywords');
    return (response.data['data'] as List).cast<String>();
  }

  Future<List<String>> getSuggestions(String query) async {
    final response = await _apiClient.dio.get('/search/suggestions', queryParameters: {'q': query});
    return (response.data['data'] as List).cast<String>();
  }
}

class SearchResult {
  final List<Novel> hits;
  final int total;

  const SearchResult({required this.hits, required this.total});
}
