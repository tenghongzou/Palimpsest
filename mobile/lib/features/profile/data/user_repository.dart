import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../auth/domain/entities/user.dart';
import '../domain/entities/reading_stats.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(apiClientProvider));
});

/// Server-side reading position of a novel (GET /reading-progress/{id}).
class RemoteProgress {
  final String chapterId;
  final int paragraphIndex;
  final double scrollOffset;
  final DateTime? readAt;

  const RemoteProgress({required this.chapterId, this.paragraphIndex = 0, this.scrollOffset = 0, this.readAt});
}

class UserRepository {
  final ApiClient _api;

  UserRepository(this._api);

  /// PATCH /users/me; omitted fields stay unchanged.
  Future<User> updateProfile({String? nickname, String? bio}) async {
    final response = await _api.dio.patch('/users/me', data: {
      if (nickname != null) 'nickname': nickname,
      if (bio != null) 'bio': bio,
    });
    return User.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// POST /users/me/avatar (JPEG, PNG, WebP or GIF, at most 2 MB).
  Future<User> uploadAvatar(List<int> bytes, String filename) async {
    final form = FormData.fromMap({'avatar': MultipartFile.fromBytes(bytes, filename: filename)});
    final response = await _api.dio.post('/users/me/avatar', data: form);
    return User.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.dio.put('/users/me/password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  /// [period] is daily (7 days), weekly (8 weeks) or monthly (12 months).
  Future<ReadingStats> getReadingStats({String period = 'daily'}) async {
    final response = await _api.dio.get('/users/me/reading-stats', queryParameters: {'period': period});
    return ReadingStats.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Paginated<ReadingHistoryEntry>> getReadingHistory({int page = 1, int pageSize = 20}) async {
    final response = await _api.dio.get('/reading-history', queryParameters: {'page': page, 'page_size': pageSize});
    return Paginated.fromJson(response.data['data'] as Map<String, dynamic>, ReadingHistoryEntry.fromJson);
  }

  /// The saved position in a novel, or null if never read.
  Future<RemoteProgress?> getProgress(String novelId) async {
    try {
      final response = await _api.dio.get('/reading-progress/$novelId');
      final data = response.data['data'] as Map<String, dynamic>;
      return RemoteProgress(
        chapterId: data['chapter_id'] as String,
        paragraphIndex: data['paragraph_index'] as int? ?? 0,
        scrollOffset: (data['scroll_offset'] as num?)?.toDouble() ?? 0,
        readAt: DateTime.tryParse(data['read_at'] as String? ?? ''),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
