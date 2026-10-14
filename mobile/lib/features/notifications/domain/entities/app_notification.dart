import '../../../../core/utils/formatters.dart';
import '../../../community/domain/entities/community.dart';

/// `NotificationType` values of the API.
class NotificationTypes {
  static const chapterUpdate = 'chapter_update';
  static const commentReply = 'comment_reply';
  static const system = 'system';
}

/// An in-app notification (`Notification` in the API). Named AppNotification
/// so it does not clash with Flutter's widgets `Notification`.
class AppNotification {
  final String id;

  /// One of [NotificationTypes]; unknown future types are kept as sent.
  final String type;
  final String title;
  final String? body;
  final String? novelId;
  final String? chapterId;

  /// For `comment_reply`, the thread's top-level comment.
  final String? commentId;
  final DateTime? readAt;
  final DateTime? createdAt;
  final UserBrief? actor;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.novelId,
    this.chapterId,
    this.commentId,
    this.readAt,
    this.createdAt,
    this.actor,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    String? str(String key) {
      final v = json[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? NotificationTypes.system,
      title: json['title'] as String? ?? '',
      body: str('body'),
      novelId: str('novel_id'),
      chapterId: str('chapter_id'),
      commentId: str('comment_id'),
      readAt: parseDateTime(json['read_at']),
      createdAt: parseDateTime(json['created_at']),
      actor: UserBrief.fromJson(json['actor']),
    );
  }

  AppNotification markedRead([DateTime? at]) => isRead
      ? this
      : AppNotification(
          id: id,
          type: type,
          title: title,
          body: body,
          novelId: novelId,
          chapterId: chapterId,
          commentId: commentId,
          readAt: at ?? DateTime.now().toUtc(),
          createdAt: createdAt,
          actor: actor,
        );

  /// Where tapping the notification goes, or null when it has no link (e.g.
  /// `system` announcements, whose body is shown instead).
  String? get location {
    switch (type) {
      case NotificationTypes.chapterUpdate:
        if (chapterId != null) return '/read/$chapterId';
        return novelId == null ? null : '/novel/$novelId';
      case NotificationTypes.commentReply:
        if (chapterId == null) return novelId == null ? null : '/novel/$novelId';
        return commentId == null ? '/read/$chapterId' : '/read/$chapterId?comment=$commentId';
    }
    return null;
  }
}
