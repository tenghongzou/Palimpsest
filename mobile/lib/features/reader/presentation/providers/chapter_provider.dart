import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/reader_repository.dart';
import '../../domain/entities/chapter.dart';

final chapterProvider = FutureProvider.family<Chapter, String>((ref, chapterId) async {
  final repo = ref.read(readerRepositoryProvider);
  return repo.getChapter(chapterId);
});
