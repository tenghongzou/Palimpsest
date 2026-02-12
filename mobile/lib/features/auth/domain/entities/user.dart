class User {
  final String id;
  final String username;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final String role;
  final String languagePref;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.nickname,
    this.avatarUrl,
    this.role = 'reader',
    this.languagePref = 'zh-TW',
  });
}
