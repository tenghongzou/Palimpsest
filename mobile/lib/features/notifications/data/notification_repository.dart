import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../domain/entities/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(apiClientProvider));
});

/// GET/PUT/DELETE /notifications (signed in only).
class NotificationRepository {
  final ApiClient _api;

  NotificationRepository(this._api);

  Future<Paginated<AppNotification>> list({int page = 1, int pageSize = 20, bool unreadOnly = false}) async {
    final response = await _api.dio.get('/notifications', queryParameters: {
      'page': page,
      'page_size': pageSize,
      if (unreadOnly) 'unread_only': true,
    });
    return Paginated.fromJson(response.data['data'] as Map<String, dynamic>, AppNotification.fromJson);
  }

  Future<int> unreadCount() async {
    final response = await _api.dio.get('/notifications/unread-count');
    return (response.data['data']['count'] as num?)?.toInt() ?? 0;
  }

  /// Returns how many notifications were unread.
  Future<int> markAllRead() async {
    final response = await _api.dio.put('/notifications/read-all');
    return (response.data['data']?['updated'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) => _api.dio.put('/notifications/$id/read');

  Future<void> delete(String id) => _api.dio.delete('/notifications/$id');
}
