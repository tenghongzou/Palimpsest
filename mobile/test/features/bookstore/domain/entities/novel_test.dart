import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/bookstore/domain/entities/novel.dart';

void main() {
  group('Novel', () {
    test('creation with required fields', () {
      const novel = Novel(
        id: 'n-001',
        title: 'Test Novel',
        authorName: 'Author A',
      );

      expect(novel.id, 'n-001');
      expect(novel.title, 'Test Novel');
      expect(novel.authorName, 'Author A');
    });

    test('default status is ongoing', () {
      const novel = Novel(
        id: 'n-001',
        title: 'Test Novel',
        authorName: 'Author A',
      );

      expect(novel.status, 'ongoing');
    });

    test('default language is zh-TW', () {
      const novel = Novel(
        id: 'n-001',
        title: 'Test Novel',
        authorName: 'Author A',
      );

      expect(novel.language, 'zh-TW');
    });

    test('default counters are 0', () {
      const novel = Novel(
        id: 'n-001',
        title: 'Test Novel',
        authorName: 'Author A',
      );

      expect(novel.totalWords, 0);
      expect(novel.totalChapters, 0);
      expect(novel.viewCount, 0);
      expect(novel.favoriteCount, 0);
      expect(novel.avgRating, 0);
    });

    test('empty categories and tags by default', () {
      const novel = Novel(
        id: 'n-001',
        title: 'Test Novel',
        authorName: 'Author A',
      );

      expect(novel.categories, isEmpty);
      expect(novel.tags, isEmpty);
    });

    test('creation with all fields set', () {
      final now = DateTime(2025, 1, 15, 10, 30);
      final novel = Novel(
        id: 'n-002',
        title: 'Full Novel',
        authorName: 'Author B',
        coverUrl: 'https://cdn.example.com/cover.jpg',
        description: 'A thrilling story.',
        status: 'completed',
        language: 'zh-CN',
        totalWords: 500000,
        totalChapters: 200,
        viewCount: 100000,
        favoriteCount: 5000,
        avgRating: 4.5,
        latestChapterTitle: 'Chapter 200: The End',
        latestChapterAt: now,
        categories: const ['fantasy', 'adventure'],
        tags: const ['epic', 'magic', 'hero'],
      );

      expect(novel.id, 'n-002');
      expect(novel.title, 'Full Novel');
      expect(novel.authorName, 'Author B');
      expect(novel.coverUrl, 'https://cdn.example.com/cover.jpg');
      expect(novel.description, 'A thrilling story.');
      expect(novel.status, 'completed');
      expect(novel.language, 'zh-CN');
      expect(novel.totalWords, 500000);
      expect(novel.totalChapters, 200);
      expect(novel.viewCount, 100000);
      expect(novel.favoriteCount, 5000);
      expect(novel.avgRating, 4.5);
      expect(novel.latestChapterTitle, 'Chapter 200: The End');
      expect(novel.latestChapterAt, now);
      expect(novel.categories, ['fantasy', 'adventure']);
      expect(novel.tags, ['epic', 'magic', 'hero']);
    });
  });
}
