/// Languages the reader can translate a chapter into, with their labels.
const translationLanguages = <String, String>{
  'zh-TW': '繁體中文',
  'zh-CN': '简体中文',
  'en': 'English',
};

class ChapterTranslation {
  final String chapterId;
  final String originalLang;
  final String targetLang;
  final String title;
  final String content;
  final bool isCached;

  const ChapterTranslation({
    required this.chapterId,
    required this.originalLang,
    required this.targetLang,
    required this.title,
    required this.content,
    this.isCached = false,
  });

  factory ChapterTranslation.fromJson(Map<String, dynamic> json, {String fallbackTitle = ''}) =>
      ChapterTranslation(
        chapterId: json['chapter_id'] as String,
        originalLang: json['original_lang'] as String? ?? '',
        targetLang: json['target_lang'] as String,
        title: json['translated_title'] as String? ?? fallbackTitle,
        content: json['translated_content'] as String? ?? '',
        isCached: json['is_cached'] as bool? ?? false,
      );
}

/// A chapter in the table of contents.
class TocEntry {
  final String id;
  final String title;
  final int chapterNumber;
  final int wordCount;
  final bool isDownloaded;

  const TocEntry({
    required this.id,
    required this.title,
    required this.chapterNumber,
    this.wordCount = 0,
    this.isDownloaded = false,
  });
}

/// The table of contents, possibly built from chapters stored offline.
class Toc {
  final List<TocEntry> entries;
  final bool fromCache;

  const Toc({required this.entries, this.fromCache = false});
}
