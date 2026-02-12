class Chapter {
  final String id;
  final String novelId;
  final String title;
  final String content;
  final int chapterNumber;
  final int wordCount;
  final String? prevChapterId;
  final String? nextChapterId;

  const Chapter({
    required this.id,
    required this.novelId,
    required this.title,
    required this.content,
    required this.chapterNumber,
    this.wordCount = 0,
    this.prevChapterId,
    this.nextChapterId,
  });
}
