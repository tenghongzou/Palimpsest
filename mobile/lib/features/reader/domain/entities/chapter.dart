class Chapter {
  final String id;
  final String novelId;
  final String title;
  final String content;
  final int chapterNumber;
  final int wordCount;
  final String? prevChapterId;
  final String? nextChapterId;

  /// True when served from the offline cache because the network failed.
  final bool fromCache;

  const Chapter({
    required this.id,
    required this.novelId,
    required this.title,
    required this.content,
    required this.chapterNumber,
    this.wordCount = 0,
    this.prevChapterId,
    this.nextChapterId,
    this.fromCache = false,
  });
}
