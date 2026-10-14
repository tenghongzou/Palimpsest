import '../../../../core/utils/formatters.dart';
import '../../../bookstore/domain/entities/novel.dart';

class StatsBucket {
  final DateTime start;
  final int chapters;
  final int words;
  final int seconds;

  const StatsBucket({required this.start, this.chapters = 0, this.words = 0, this.seconds = 0});
}

/// GET /users/me/reading-stats.
class ReadingStats {
  final int totalReadWords;
  final int totalReadSeconds;
  final int chaptersRead;
  final int novelsRead;
  final int bookshelfCount;
  final int bookmarkCount;
  final int reviewCount;
  final String period;
  final List<StatsBucket> buckets;

  const ReadingStats({
    this.totalReadWords = 0,
    this.totalReadSeconds = 0,
    this.chaptersRead = 0,
    this.novelsRead = 0,
    this.bookshelfCount = 0,
    this.bookmarkCount = 0,
    this.reviewCount = 0,
    this.period = 'daily',
    this.buckets = const [],
  });

  factory ReadingStats.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ReadingStats(
      totalReadWords: n('total_read_words'),
      totalReadSeconds: n('total_read_seconds'),
      chaptersRead: n('chapters_read'),
      novelsRead: n('novels_read'),
      bookshelfCount: n('bookshelf_count'),
      bookmarkCount: n('bookmark_count'),
      reviewCount: n('review_count'),
      period: json['period'] as String? ?? 'daily',
      buckets: (json['buckets'] as List? ?? const []).map((e) {
        final b = e as Map<String, dynamic>;
        return StatsBucket(
          start: parseDateTime(b['start']) ?? DateTime.now(),
          chapters: (b['chapters'] as num?)?.toInt() ?? 0,
          words: (b['words'] as num?)?.toInt() ?? 0,
          seconds: (b['seconds'] as num?)?.toInt() ?? 0,
        );
      }).toList(),
    );
  }
}

/// An entry of GET /reading-history.
class ReadingHistoryEntry {
  final String id;
  final String novelId;
  final String chapterId;
  final DateTime readAt;
  final int duration;
  final Novel? novel;
  final String? chapterTitle;
  final int? chapterNumber;

  const ReadingHistoryEntry({
    required this.id,
    required this.novelId,
    required this.chapterId,
    required this.readAt,
    this.duration = 0,
    this.novel,
    this.chapterTitle,
    this.chapterNumber,
  });

  factory ReadingHistoryEntry.fromJson(Map<String, dynamic> json) {
    final novel = json['novel'] as Map<String, dynamic>?;
    final chapter = json['chapter'] as Map<String, dynamic>?;
    return ReadingHistoryEntry(
      id: json['id'] as String,
      novelId: json['novel_id'] as String,
      chapterId: json['chapter_id'] as String,
      readAt: parseDateTime(json['read_at']) ?? DateTime.now(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      novel: novel == null ? null : Novel.fromJson(novel),
      chapterTitle: chapter?['title'] as String?,
      chapterNumber: chapter?['chapter_number'] as int?,
    );
  }
}
