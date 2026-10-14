import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/bookshelf_item.dart';

final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) {
  return BookshelfRepository(ref.read(apiClientProvider));
});

/// `sort_by` values of GET /bookshelf.
const bookshelfSortOptions = ['recent', 'added', 'title'];

class BookshelfRepository {
  final ApiClient _apiClient;

  BookshelfRepository(this._apiClient);

  Future<List<BookshelfItem>> getBookshelf({String sortBy = 'recent'}) async {
    final response = await _apiClient.dio.get('/bookshelf', queryParameters: {'sort_by': sortBy});
    return (response.data['data'] as List).map((e) => parseItem(e as Map<String, dynamic>)).toList();
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

  Future<void> batchRemove(List<String> novelIds) async {
    await _apiClient.dio.post('/bookshelf/batch-remove', data: {'novel_ids': novelIds});
  }

  Future<void> setGroup(String novelId, String groupName) => updateItem(novelId, groupName: groupName);

  /// PATCH /bookshelf/{novelId}; omitted fields stay unchanged.
  Future<void> updateItem(String novelId, {String? groupName, bool? isNotified}) async {
    await _apiClient.dio.patch('/bookshelf/$novelId', data: {
      if (groupName != null) 'group_name': groupName,
      if (isNotified != null) 'is_notified': isNotified,
    });
  }

  /// [scrollOffset] is the position within the chapter, from 0.0 to 1.0.
  Future<void> updateProgress(String novelId, String chapterId, double scrollOffset) async {
    await _apiClient.dio.put('/reading-progress/$novelId', data: {
      'chapter_id': chapterId,
      'scroll_offset': scrollOffset,
    });
  }

  /// Parses a `BookshelfEntry`.
  static BookshelfItem parseItem(Map<String, dynamic> json) {
    final novel = json['novel'] as Map<String, dynamic>?;
    final rp = json['reading_progress'] as Map<String, dynamic>?;
    final progress = rp == null
        ? null
        : ReadingProgressInfo(
            chapterId: rp['chapter_id'] as String?,
            chapterTitle: rp['chapter_title'] as String? ?? '',
            chapterNumber: rp['chapter_number'] as int? ?? 0,
            percentage: (rp['percentage'] as num?)?.toDouble() ?? 0,
            readAt: parseDateTime(rp['read_at']),
          );
    final cover = novel?['cover_url'] as String?;
    return BookshelfItem(
      id: json['id'] as String,
      novelId: json['novel_id'] as String,
      novelTitle: novel?['title'] as String? ?? '',
      authorName: novel?['author_name'] as String?,
      coverUrl: cover == null || cover.isEmpty ? null : cover,
      latestChapterTitle: novel?['latest_chapter_title'] as String?,
      groupName: json['group_name'] as String? ?? 'default',
      hasUpdate: json['has_update'] as bool? ?? false,
      // The server defaults to on.
      isNotified: json['is_notified'] as bool? ?? true,
      progress: progress,
      addedAt: parseDateTime(json['added_at']) ?? DateTime.now(),
    );
  }
}
