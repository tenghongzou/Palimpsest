class BookshelfItem {
  final String id;
  final String novelId;
  final String novelTitle;
  final String? coverUrl;
  final String? latestChapterTitle;
  final String groupName;
  final bool hasUpdate;
  final ReadingProgressInfo? progress;
  final DateTime addedAt;

  const BookshelfItem({
    required this.id,
    required this.novelId,
    required this.novelTitle,
    this.coverUrl,
    this.latestChapterTitle,
    this.groupName = 'default',
    this.hasUpdate = false,
    this.progress,
    required this.addedAt,
  });
}

class ReadingProgressInfo {
  final String chapterTitle;
  final int chapterNumber;
  final double percentage;

  const ReadingProgressInfo({
    required this.chapterTitle,
    required this.chapterNumber,
    required this.percentage,
  });
}
