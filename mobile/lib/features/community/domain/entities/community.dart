import '../../../../core/utils/formatters.dart';

class UserBrief {
  final String id;
  final String username;
  final String nickname;
  final String? avatarUrl;

  const UserBrief({required this.id, required this.username, required this.nickname, this.avatarUrl});

  String get displayName => nickname.isNotEmpty ? nickname : username;

  static UserBrief? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return UserBrief(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class Review {
  final String id;
  final String userId;
  final String novelId;
  final String title;
  final String content;
  final double rating;
  final int likeCount;
  final bool likedByMe;
  final UserBrief? user;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.title,
    required this.content,
    required this.rating,
    this.likeCount = 0,
    this.likedByMe = false,
    this.user,
    this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        novelId: json['novel_id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        likeCount: json['like_count'] as int? ?? 0,
        likedByMe: json['liked_by_me'] as bool? ?? false,
        user: UserBrief.fromJson(json['user']),
        createdAt: parseDateTime(json['created_at']),
      );

  Review withLike({required bool liked, required int likeCount}) => Review(
        id: id,
        userId: userId,
        novelId: novelId,
        title: title,
        content: content,
        rating: rating,
        likeCount: likeCount,
        likedByMe: liked,
        user: user,
        createdAt: createdAt,
      );
}

class Comment {
  final String id;
  final String userId;
  final String chapterId;
  final String? parentId;
  final String content;
  final int? paragraphIndex;
  final int likeCount;
  final bool likedByMe;
  final UserBrief? user;
  final List<Comment> replies;
  final DateTime? createdAt;

  const Comment({
    required this.id,
    required this.userId,
    required this.chapterId,
    this.parentId,
    required this.content,
    this.paragraphIndex,
    this.likeCount = 0,
    this.likedByMe = false,
    this.user,
    this.replies = const [],
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        chapterId: json['chapter_id'] as String,
        parentId: json['parent_id'] as String?,
        content: json['content'] as String? ?? '',
        paragraphIndex: json['paragraph_index'] as int?,
        likeCount: json['like_count'] as int? ?? 0,
        likedByMe: json['liked_by_me'] as bool? ?? false,
        user: UserBrief.fromJson(json['user']),
        replies: (json['replies'] as List? ?? const [])
            .map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: parseDateTime(json['created_at']),
      );

  Comment copyWith({int? likeCount, bool? likedByMe, List<Comment>? replies}) => Comment(
        id: id,
        userId: userId,
        chapterId: chapterId,
        parentId: parentId,
        content: content,
        paragraphIndex: paragraphIndex,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        user: user,
        replies: replies ?? this.replies,
        createdAt: createdAt,
      );
}

/// Result of liking or unliking.
class LikeResult {
  final bool liked;
  final int likeCount;

  const LikeResult({required this.liked, required this.likeCount});
}

/// Report reasons accepted by POST /reports (labels: report_dialog.dart).
const reportReasons = ['spam', 'abuse', 'spoiler', 'copyright', 'inappropriate', 'other'];
