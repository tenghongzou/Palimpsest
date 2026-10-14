import '../../../../core/utils/formatters.dart';

/// A bookmark at a paragraph of a chapter. Ids are generated on the client
/// so bookmarks created offline keep their identity once synced.
class Bookmark {
  final String id;
  final String novelId;
  final String chapterId;
  final String? chapterTitle;
  final int paragraphIndex;
  final String? note;
  final DateTime createdAt;
  final bool isSynced;

  const Bookmark({
    required this.id,
    required this.novelId,
    required this.chapterId,
    this.chapterTitle,
    this.paragraphIndex = 0,
    this.note,
    required this.createdAt,
    this.isSynced = false,
  });

  /// Parses a bookmark from the API (`Bookmark` schema).
  factory Bookmark.fromJson(Map<String, dynamic> json) {
    final chapter = json['chapter'] as Map<String, dynamic>?;
    return Bookmark(
      id: json['id'] as String,
      novelId: json['novel_id'] as String,
      chapterId: json['chapter_id'] as String,
      chapterTitle: chapter?['title'] as String?,
      paragraphIndex: json['paragraph_index'] as int? ?? 0,
      note: json['note'] as String?,
      createdAt: parseDateTime(json['created_at']) ?? DateTime.now(),
      isSynced: true,
    );
  }

  /// The `BookmarkInput` body used by POST /bookmarks/sync.
  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'chapter_id': chapterId,
        'paragraph_index': paragraphIndex,
        if (note != null && note!.isNotEmpty) 'note': note,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
