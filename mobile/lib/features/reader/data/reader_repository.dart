import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/offline_store.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/chapter.dart';
import '../domain/entities/chapter_translation.dart';

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return ReaderRepository(ref.read(apiClientProvider), ref.read(offlineStoreProvider));
});

class ReaderRepository {
  final ApiClient _apiClient;
  final Future<OfflineStore> Function() _store;

  ReaderRepository(this._apiClient, this._store);

  /// Fetches a chapter and caches it for offline reading. When the request
  /// fails for network reasons, the cached copy is returned instead, with
  /// prev/next links pointing at the closest chapters stored offline.
  Future<Chapter> getChapter(String chapterId) async {
    try {
      final chapter = await fetchChapter(chapterId);
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

  /// GET /chapters/{id} without touching the cache. Bulk downloads pass
  /// [countView] false so they do not count as reads of the novel.
  Future<Chapter> fetchChapter(String chapterId, {bool countView = true}) async {
    final response = await _apiClient.dio.get(
      '/chapters/$chapterId',
      queryParameters: countView ? null : {'count_view': 'false'},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return Chapter(
      id: data['id'] as String,
      novelId: data['novel_id'] as String,
      title: data['title'] as String,
      content: data['content'] as String? ?? '',
      chapterNumber: data['chapter_number'] as int,
      wordCount: data['word_count'] as int? ?? 0,
      prevChapter: ChapterRef.fromJson(data['prev_chapter']),
      nextChapter: ChapterRef.fromJson(data['next_chapter']),
    );
  }

  /// The novel's table of contents; offline it lists the chapters stored on
  /// the device.
  Future<Toc> getToc(String novelId) async {
    final store = await _storeOrNull();
    final downloaded = await store?.downloadedChapterIds(novelId) ?? const <String>{};
    try {
      final response = await _apiClient.dio.get('/novels/$novelId/chapters', queryParameters: {'order': 'asc'});
      final entries = (response.data['data'] as List).map((e) {
        final id = e['id'] as String;
        return TocEntry(
          id: id,
          title: e['title'] as String,
          chapterNumber: e['chapter_number'] as int,
          wordCount: e['word_count'] as int? ?? 0,
          isDownloaded: downloaded.contains(id),
        );
      }).toList();
      return Toc(entries: entries);
    } on DioException catch (e) {
      if (e.response != null || store == null) rethrow;
      final local = await store.listChapters(novelId);
      if (local.isEmpty) rethrow;
      return Toc(
        fromCache: true,
        entries: local
            .map((c) => TocEntry(
                  id: c.id,
                  title: c.title,
                  chapterNumber: c.chapterNumber,
                  wordCount: c.wordCount,
                  isDownloaded: c.isDownloaded,
                ))
            .toList(),
      );
    }
  }

  /// Translates a chapter (POST /translation/chapter), using the local
  /// translation cache first. Throws the DioException on failure; a 503
  /// means no provider is configured for the target language.
  Future<ChapterTranslation> translateChapter(String chapterId, String targetLang, {String fallbackTitle = ''}) async {
    final store = await _storeOrNull();
    final cached = await store?.getTranslation(chapterId, targetLang);
    if (cached != null) {
      return ChapterTranslation(
        chapterId: chapterId,
        originalLang: cached.sourceLang,
        targetLang: targetLang,
        title: cached.title,
        content: cached.content,
        isCached: true,
      );
    }
    final response = await _apiClient.dio.post('/translation/chapter', data: {
      'chapter_id': chapterId,
      'target_lang': targetLang,
    });
    final translation = ChapterTranslation.fromJson(
      response.data['data'] as Map<String, dynamic>,
      fallbackTitle: fallbackTitle,
    );
    try {
      await store?.saveTranslation(
        chapterId: chapterId,
        sourceLang: translation.originalLang,
        targetLang: targetLang,
        title: translation.title,
        content: translation.content,
      );
    } catch (_) {}
    return translation;
  }

  Future<OfflineStore?> _storeOrNull() async {
    try {
      return await _store();
    } catch (_) {
      return null;
    }
  }
}
