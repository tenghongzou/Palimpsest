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
  final int reviewCount;
  final double avgRating;
  final String? latestChapterId;
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
    this.reviewCount = 0,
    this.avgRating = 0,
    this.latestChapterId,
    this.latestChapterTitle,
    this.latestChapterAt,
    this.categories = const [],
    this.tags = const [],
  });

  /// Parses the API `Novel` schema (also search hits, a subset of it).
  factory Novel.fromJson(Map<String, dynamic> json) {
    List<String> names(Object? list) => (list as List? ?? const [])
        .map((e) => e is Map ? e['name'] as String? ?? '' : '$e')
        .where((n) => n.isNotEmpty)
        .toList();
    final cover = json['cover_url'] as String?;
    return Novel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      coverUrl: cover == null || cover.isEmpty ? null : cover,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'ongoing',
      language: json['language'] as String? ?? 'zh-TW',
      totalWords: (json['total_words'] as num?)?.toInt() ?? 0,
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      latestChapterId: json['latest_chapter_id'] as String?,
      latestChapterTitle: json['latest_chapter_title'] as String?,
      latestChapterAt: json['latest_chapter_at'] is String
          ? DateTime.tryParse(json['latest_chapter_at'] as String)
          : null,
      categories: names(json['categories']),
      tags: names(json['tags']),
    );
  }
}
