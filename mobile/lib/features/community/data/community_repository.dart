import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../domain/entities/community.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.read(apiClientProvider));
});

/// Reviews, chapter comments, likes and reports.
class CommunityRepository {
  final ApiClient _api;

  CommunityRepository(this._api);

  Future<Paginated<Review>> getReviews(String novelId, {int page = 1, int pageSize = 10, String sortBy = 'latest'}) async {
    final response = await _api.dio.get('/novels/$novelId/reviews', queryParameters: {
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
    });
    return Paginated.fromJson(response.data['data'] as Map<String, dynamic>, Review.fromJson);
  }

  /// Rating is 0.5–5 in half stars; a second review by the same user is a 409.
  Future<Review> createReview(String novelId, {required String title, required String content, required double rating}) async {
    final response = await _api.dio.post('/novels/$novelId/reviews', data: {
      'title': title,
      'content': content,
      'rating': rating,
    });
    return Review.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Review> updateReview(String reviewId, {required String title, required String content, required double rating}) async {
    final response = await _api.dio.put('/reviews/$reviewId', data: {
      'title': title,
      'content': content,
      'rating': rating,
    });
    return Review.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteReview(String reviewId) => _api.dio.delete('/reviews/$reviewId');

  Future<LikeResult> setReviewLike(String reviewId, bool like) =>
      _like(like ? _api.dio.post('/reviews/$reviewId/like') : _api.dio.delete('/reviews/$reviewId/like'));

  /// With [paragraphIndex], only the comments on that paragraph.
  Future<Paginated<Comment>> getComments(String chapterId,
      {int page = 1, int pageSize = 20, String sortBy = 'latest', int? paragraphIndex}) async {
    final response = await _api.dio.get('/chapters/$chapterId/comments', queryParameters: {
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
    });
    return Paginated.fromJson(response.data['data'] as Map<String, dynamic>, Comment.fromJson);
  }

  /// Top-level comment count per paragraph index; paragraphs without
  /// comments are absent.
  Future<Map<int, int>> getParagraphCounts(String chapterId) async {
    final response = await _api.dio.get('/chapters/$chapterId/comments/paragraph-counts');
    return parseParagraphCounts(response.data['data']);
  }

  /// Parses `[{paragraph_index, count}]`.
  static Map<int, int> parseParagraphCounts(Object? data) {
    final counts = <int, int>{};
    for (final e in data is List ? data : const []) {
      if (e is! Map) continue;
      final index = (e['paragraph_index'] as num?)?.toInt();
      final count = (e['count'] as num?)?.toInt() ?? 0;
      if (index != null && index >= 0 && count > 0) counts[index] = count;
    }
    return counts;
  }

  Future<Comment> createComment(String chapterId, String content, {String? parentId, int? paragraphIndex}) async {
    final response = await _api.dio.post('/chapters/$chapterId/comments', data: {
      'content': content,
      if (parentId != null) 'parent_id': parentId,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
    });
    return Comment.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// The thread holding [commentId] (a top-level comment or a reply): its
  /// top-level comment with the replies. A 404 means it was deleted.
  Future<Comment> getCommentThread(String commentId) async {
    final response = await _api.dio.get('/comments/$commentId');
    return Comment.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteComment(String commentId) => _api.dio.delete('/comments/$commentId');

  Future<LikeResult> setCommentLike(String commentId, bool like) =>
      _like(like ? _api.dio.post('/comments/$commentId/like') : _api.dio.delete('/comments/$commentId/like'));

  /// [targetType] is review, comment, novel, chapter or user; [reason] one of
  /// [reportReasons].
  Future<void> report({required String targetType, required String targetId, required String reason, String? description}) async {
    await _api.dio.post('/reports', data: {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
    });
  }

  Future<LikeResult> _like(Future<dynamic> request) async {
    final response = await request;
    final data = response.data['data'] as Map<String, dynamic>;
    return LikeResult(liked: data['liked'] as bool, likeCount: data['like_count'] as int? ?? 0);
  }
}
