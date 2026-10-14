class User {
  final String id;
  final String username;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final String? bio;
  final String role;
  final String languagePref;
  final int totalReadWords;
  final int totalReadSeconds;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.nickname,
    this.avatarUrl,
    this.bio,
    this.role = 'reader',
    this.languagePref = 'zh-TW',
    this.totalReadWords = 0,
    this.totalReadSeconds = 0,
  });

  String get displayName => nickname.isNotEmpty ? nickname : username;

  factory User.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'] as String?;
    return User(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
      bio: json['bio'] as String?,
      role: json['role'] as String? ?? 'reader',
      languagePref: json['language_pref'] as String? ?? 'zh-TW',
      totalReadWords: (json['total_read_words'] as num?)?.toInt() ?? 0,
      totalReadSeconds: (json['total_read_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'nickname': nickname,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bio != null) 'bio': bio,
        'role': role,
        'language_pref': languagePref,
        'total_read_words': totalReadWords,
        'total_read_seconds': totalReadSeconds,
      };
}
