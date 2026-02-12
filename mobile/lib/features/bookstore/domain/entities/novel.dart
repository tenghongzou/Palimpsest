class Novel {
  final String id;
  final String title;
  final String authorName;
  final String? coverUrl;
  final String? description;
  final String status;
  final String language;
  final int totalWords;
  final int totalChapters;
  final int viewCount;
  final int favoriteCount;
  final double avgRating;
  final String? latestChapterTitle;
  final DateTime? latestChapterAt;
  final List<String> categories;
  final List<String> tags;

  const Novel({
    required this.id,
    required this.title,
    required this.authorName,
    this.coverUrl,
    this.description,
    this.status = 'ongoing',
    this.language = 'zh-TW',
    this.totalWords = 0,
    this.totalChapters = 0,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.avgRating = 0,
    this.latestChapterTitle,
    this.latestChapterAt,
    this.categories = const [],
    this.tags = const [],
  });
}
