class BookshelfItem {
  final String id;
  final String novelId;
  final String novelTitle;
  final String? coverUrl;
  final String? latestChapterTitle;
  final String? authorName;
  final String groupName;
  final bool hasUpdate;

  /// Whether newly published chapters send a notification.
  final bool isNotified;
  final ReadingProgressInfo? progress;
  final DateTime addedAt;

  const BookshelfItem({
    required this.id,
    required this.novelId,
    required this.novelTitle,
    this.coverUrl,
    this.latestChapterTitle,
    this.authorName,
    this.groupName = 'default',
    this.hasUpdate = false,
    this.isNotified = true,
    this.progress,
    required this.addedAt,
  });

  BookshelfItem copyWith({String? groupName, bool? isNotified}) => BookshelfItem(
        id: id,
        novelId: novelId,
        novelTitle: novelTitle,
        coverUrl: coverUrl,
        latestChapterTitle: latestChapterTitle,
        authorName: authorName,
        groupName: groupName ?? this.groupName,
        hasUpdate: hasUpdate,
        isNotified: isNotified ?? this.isNotified,
        progress: progress,
        addedAt: addedAt,
      );
}

class ReadingProgressInfo {
  final String? chapterId;
  final String chapterTitle;
  final int chapterNumber;

  /// Share of the novel read, 0–100.
  final double percentage;
  final DateTime? readAt;

  const ReadingProgressInfo({
    this.chapterId,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.percentage,
    this.readAt,
  });
}
