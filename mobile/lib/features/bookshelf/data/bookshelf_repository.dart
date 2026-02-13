import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/bookshelf_item.dart';

final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) {
  return BookshelfRepository(ref.read(apiClientProvider));
});

class BookshelfRepository {
  final ApiClient _apiClient;

  BookshelfRepository(this._apiClient);

  Future<List<BookshelfItem>> getBookshelf({String sort = 'recent'}) async {
    final response = await _apiClient.dio.get('/bookshelf', queryParameters: {'sort': sort});
    return (response.data['data'] as List).map((e) => _parseItem(e)).toList();
  }

  Future<void> addToBookshelf(String novelId, {String groupName = 'default'}) async {
    await _apiClient.dio.post('/bookshelf', data: {
      'novel_id': novelId,
      'group_name': groupName,
    });
  }

  Future<void> removeFromBookshelf(String novelId) async {
    await _apiClient.dio.delete('/bookshelf/$novelId');
  }

  Future<void> updateProgress(String novelId, String chapterId, double progress) async {
    await _apiClient.dio.put('/bookshelf/progress', data: {
      'novel_id': novelId,
      'chapter_id': chapterId,
      'progress': progress,
    });
  }

  BookshelfItem _parseItem(Map<String, dynamic> json) {
    final novel = json['novel'] as Map<String, dynamic>?;
    ReadingProgressInfo? progress;
    if (json['last_read_chapter_id'] != null) {
      progress = ReadingProgressInfo(
        chapterTitle: json['last_read_chapter_title'] as String? ?? '',
        chapterNumber: json['last_read_chapter_number'] as int? ?? 0,
        percentage: (json['progress'] as num?)?.toDouble() ?? 0,
      );
    }

    return BookshelfItem(
      id: json['id'] as String,
      novelId: json['novel_id'] as String,
      novelTitle: novel?['title'] as String? ?? '',
      coverUrl: novel?['cover_url'] as String?,
      latestChapterTitle: novel?['latest_chapter_title'] as String?,
      groupName: json['group_name'] as String? ?? 'default',
      hasUpdate: false,
      progress: progress,
      addedAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
