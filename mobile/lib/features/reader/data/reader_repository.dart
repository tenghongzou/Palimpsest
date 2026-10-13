import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/offline_store.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/chapter.dart';

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return ReaderRepository(
    ref.read(apiClientProvider),
    () async => OfflineStore(await DatabaseHelper.database),
  );
});

class ReaderRepository {
  final ApiClient _apiClient;
  final Future<OfflineStore> Function() _store;

  ReaderRepository(this._apiClient, this._store);

  /// Fetches a chapter and caches it for offline reading. When the request
  /// fails for network reasons, the cached copy is returned instead.
  Future<Chapter> getChapter(String chapterId) async {
    try {
      final response = await _apiClient.dio.get('/chapters/$chapterId');
      final data = response.data['data'];
      final chapter = Chapter(
        id: data['id'] as String,
        novelId: data['novel_id'] as String,
        title: data['title'] as String,
        content: data['content'] as String,
        chapterNumber: data['chapter_number'] as int,
        wordCount: data['word_count'] as int? ?? 0,
      );
      try {
        final store = await _store();
        await store.saveChapter(chapter);
        await store.enforceCacheLimit();
      } catch (_) {
        // Caching is best effort; reading online still works.
      }
      return chapter;
    } on DioException catch (e) {
      if (e.response != null) rethrow; // The server answered (e.g. 404): not an offline case.
      final cached = await (await _store()).getChapter(chapterId);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<String> translateChapter(String chapterId, String targetLang) async {
    final response = await _apiClient.dio.post('/translation/chapter', data: {
      'chapter_id': chapterId,
      'target_lang': targetLang,
    });
    return response.data['data']['translated_content'] as String;
  }
}
