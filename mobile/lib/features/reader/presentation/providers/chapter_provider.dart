import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/bookmark_repository.dart';
import '../../data/reader_repository.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/chapter_translation.dart';

final chapterProvider = FutureProvider.family<Chapter, String>((ref, chapterId) async {
  final repo = ref.read(readerRepositoryProvider);
  return repo.getChapter(chapterId);
});

final tocProvider = FutureProvider.autoDispose.family<Toc, String>((ref, novelId) async {
  return ref.read(readerRepositoryProvider).getToc(novelId);
});

/// Bookmarks of a novel, or of every novel when the key is null.
final bookmarksProvider = FutureProvider.autoDispose.family<List<Bookmark>, String?>((ref, novelId) async {
  return ref.read(bookmarkRepositoryProvider).list(novelId: novelId);
});
