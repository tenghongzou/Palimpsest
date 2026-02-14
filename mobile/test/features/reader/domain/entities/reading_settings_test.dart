import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/reader/domain/entities/reading_settings.dart';

void main() {
  group('ReadingSettings', () {
    test('default values are correct', () {
      const settings = ReadingSettings();

      expect(settings.fontSize, 18);
      expect(settings.lineHeight, 1.8);
      expect(settings.letterSpacing, 0.0);
      expect(settings.margin, 16);
      expect(settings.fontFamily, 'system');
      expect(settings.theme, 'white');
      expect(settings.readingMode, 'scroll');
      expect(settings.brightness, 100);
      expect(settings.keepScreenOn, isTrue);
      expect(settings.autoChapter, isTrue);
    });

    test('copyWith creates new instance with changed values', () {
      const original = ReadingSettings();
      final updated = original.copyWith(
        fontSize: 24,
        theme: 'dark',
        lineHeight: 2.0,
      );

      expect(updated.fontSize, 24);
      expect(updated.theme, 'dark');
      expect(updated.lineHeight, 2.0);
    });

    test('copyWith preserves unchanged values', () {
      const original = ReadingSettings();
      final updated = original.copyWith(fontSize: 24);

      expect(updated.fontSize, 24);
      expect(updated.lineHeight, 1.8);
      expect(updated.letterSpacing, 0.0);
      expect(updated.margin, 16);
      expect(updated.fontFamily, 'system');
      expect(updated.theme, 'white');
      expect(updated.readingMode, 'scroll');
      expect(updated.brightness, 100);
      expect(updated.keepScreenOn, isTrue);
      expect(updated.autoChapter, isTrue);
    });

    test('custom settings creation', () {
      const settings = ReadingSettings(
        fontSize: 22,
        lineHeight: 2.2,
        letterSpacing: 0.5,
        margin: 24,
        fontFamily: 'NotoSerifTC',
        theme: 'sepia',
        readingMode: 'paged',
        brightness: 80,
        keepScreenOn: false,
        autoChapter: false,
      );

      expect(settings.fontSize, 22);
      expect(settings.lineHeight, 2.2);
      expect(settings.letterSpacing, 0.5);
      expect(settings.margin, 24);
      expect(settings.fontFamily, 'NotoSerifTC');
      expect(settings.theme, 'sepia');
      expect(settings.readingMode, 'paged');
      expect(settings.brightness, 80);
      expect(settings.keepScreenOn, isFalse);
      expect(settings.autoChapter, isFalse);
    });
  });
}
