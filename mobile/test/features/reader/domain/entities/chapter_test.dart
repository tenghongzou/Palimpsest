import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/reader/domain/entities/chapter.dart';

void main() {
  group('Chapter', () {
    test('creation with required fields', () {
      const chapter = Chapter(
        id: 'c-001',
        novelId: 'n-001',
        title: 'Chapter 1: The Beginning',
        content: 'It was a dark and stormy night...',
        chapterNumber: 1,
      );

      expect(chapter.id, 'c-001');
      expect(chapter.novelId, 'n-001');
      expect(chapter.title, 'Chapter 1: The Beginning');
      expect(chapter.content, 'It was a dark and stormy night...');
      expect(chapter.chapterNumber, 1);
    });

    test('default wordCount is 0', () {
      const chapter = Chapter(
        id: 'c-001',
        novelId: 'n-001',
        title: 'Chapter 1',
        content: 'Some content.',
        chapterNumber: 1,
      );

      expect(chapter.wordCount, 0);
    });

    test('navigation IDs are null by default', () {
      const chapter = Chapter(
        id: 'c-001',
        novelId: 'n-001',
        title: 'Chapter 1',
        content: 'Some content.',
        chapterNumber: 1,
      );

      expect(chapter.prevChapterId, isNull);
      expect(chapter.nextChapterId, isNull);
    });

    test('creation with navigation IDs set', () {
      const chapter = Chapter(
        id: 'c-005',
        novelId: 'n-001',
        title: 'Chapter 5: The Middle',
        content: 'The plot thickens...',
        chapterNumber: 5,
        wordCount: 3200,
        prevChapterId: 'c-004',
        nextChapterId: 'c-006',
      );

      expect(chapter.id, 'c-005');
      expect(chapter.novelId, 'n-001');
      expect(chapter.title, 'Chapter 5: The Middle');
      expect(chapter.content, 'The plot thickens...');
      expect(chapter.chapterNumber, 5);
      expect(chapter.wordCount, 3200);
      expect(chapter.prevChapterId, 'c-004');
      expect(chapter.nextChapterId, 'c-006');
    });
  });
}
