/// A link to a neighbouring chapter (`ChapterRef` in the API).
class ChapterRef {
  final String id;
  final String title;
  final int chapterNumber;

  const ChapterRef({required this.id, required this.title, required this.chapterNumber});

  static ChapterRef? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return ChapterRef(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      chapterNumber: json['chapter_number'] as int? ?? 0,
    );
  }
}

class Chapter {
  final String id;
  final String novelId;
  final String title;
  final String content;
  final int chapterNumber;
  final int wordCount;
  final ChapterRef? prevChapter;
  final ChapterRef? nextChapter;
  final String? _prevChapterId;
  final String? _nextChapterId;

  /// True when served from the offline cache because the network failed.
  final bool fromCache;

  const Chapter({
    required this.id,
    required this.novelId,
    required this.title,
    required this.content,
    required this.chapterNumber,
    this.wordCount = 0,
    String? prevChapterId,
    String? nextChapterId,
    this.prevChapter,
    this.nextChapter,
    this.fromCache = false,
  })  : _prevChapterId = prevChapterId,
        _nextChapterId = nextChapterId;

  String? get prevChapterId => prevChapter?.id ?? _prevChapterId;
  String? get nextChapterId => nextChapter?.id ?? _nextChapterId;

  /// Non-empty paragraphs, as displayed by the reader. Bookmark and progress
  /// paragraph indexes refer to positions in this list.
  List<String> get paragraphs =>
      content.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  Chapter copyWith({ChapterRef? prevChapter, ChapterRef? nextChapter}) => Chapter(
        id: id,
        novelId: novelId,
        title: title,
        content: content,
        chapterNumber: chapterNumber,
        wordCount: wordCount,
        prevChapter: prevChapter ?? this.prevChapter,
        nextChapter: nextChapter ?? this.nextChapter,
        fromCache: fromCache,
      );
}
