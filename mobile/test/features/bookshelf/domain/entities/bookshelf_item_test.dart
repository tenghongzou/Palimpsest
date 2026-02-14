import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/bookshelf/domain/entities/bookshelf_item.dart';

void main() {
  group('BookshelfItem', () {
    test('creation with required fields', () {
      final addedAt = DateTime(2025, 3, 10);
      final item = BookshelfItem(
        id: 'bs-001',
        novelId: 'n-001',
        novelTitle: 'Test Novel',
        addedAt: addedAt,
      );

      expect(item.id, 'bs-001');
      expect(item.novelId, 'n-001');
      expect(item.novelTitle, 'Test Novel');
      expect(item.addedAt, addedAt);
    });

    test('default groupName is default', () {
      final item = BookshelfItem(
        id: 'bs-001',
        novelId: 'n-001',
        novelTitle: 'Test Novel',
        addedAt: DateTime(2025, 3, 10),
      );

      expect(item.groupName, 'default');
    });

    test('default hasUpdate is false', () {
      final item = BookshelfItem(
        id: 'bs-001',
        novelId: 'n-001',
        novelTitle: 'Test Novel',
        addedAt: DateTime(2025, 3, 10),
      );

      expect(item.hasUpdate, isFalse);
    });

    test('progress is null by default', () {
      final item = BookshelfItem(
        id: 'bs-001',
        novelId: 'n-001',
        novelTitle: 'Test Novel',
        addedAt: DateTime(2025, 3, 10),
      );

      expect(item.progress, isNull);
    });
  });

  group('ReadingProgressInfo', () {
    test('creation with required fields', () {
      const progress = ReadingProgressInfo(
        chapterTitle: 'Chapter 5: The Journey',
        chapterNumber: 5,
        percentage: 0.45,
      );

      expect(progress.chapterTitle, 'Chapter 5: The Journey');
      expect(progress.chapterNumber, 5);
      expect(progress.percentage, 0.45);
    });
  });

  group('BookshelfItem with progress', () {
    test('creation with progress info', () {
      final addedAt = DateTime(2025, 3, 10);
      const progress = ReadingProgressInfo(
        chapterTitle: 'Chapter 10: Revelation',
        chapterNumber: 10,
        percentage: 0.72,
      );

      final item = BookshelfItem(
        id: 'bs-002',
        novelId: 'n-002',
        novelTitle: 'Novel with Progress',
        coverUrl: 'https://cdn.example.com/cover.jpg',
        latestChapterTitle: 'Chapter 50: Finale',
        groupName: 'favorites',
        hasUpdate: true,
        progress: progress,
        addedAt: addedAt,
      );

      expect(item.id, 'bs-002');
      expect(item.novelId, 'n-002');
      expect(item.novelTitle, 'Novel with Progress');
      expect(item.coverUrl, 'https://cdn.example.com/cover.jpg');
      expect(item.latestChapterTitle, 'Chapter 50: Finale');
      expect(item.groupName, 'favorites');
      expect(item.hasUpdate, isTrue);
      expect(item.progress, isNotNull);
      expect(item.progress!.chapterTitle, 'Chapter 10: Revelation');
      expect(item.progress!.chapterNumber, 10);
      expect(item.progress!.percentage, 0.72);
      expect(item.addedAt, addedAt);
    });
  });
}
