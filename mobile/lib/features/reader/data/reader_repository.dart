import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/chapter.dart';

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return ReaderRepository(ref.read(apiClientProvider));
});

class ReaderRepository {
  final ApiClient _apiClient;

  ReaderRepository(this._apiClient);

  Future<Chapter> getChapter(String chapterId) async {
    final response = await _apiClient.dio.get('/chapters/$chapterId');
    final data = response.data['data'];
    return Chapter(
      id: data['id'] as String,
      novelId: data['novel_id'] as String,
      title: data['title'] as String,
      content: data['content'] as String,
      chapterNumber: data['chapter_number'] as int,
      wordCount: data['word_count'] as int? ?? 0,
    );
  }

  Future<String> translateChapter(String chapterId, String targetLang) async {
    final response = await _apiClient.dio.post('/translation/chapter', data: {
      'chapter_id': chapterId,
      'target_language': targetLang,
    });
    return response.data['data']['content'] as String;
  }
}
