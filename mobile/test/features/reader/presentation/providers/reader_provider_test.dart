import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/reader/domain/entities/reading_settings.dart';
import 'package:palimpsest/features/reader/presentation/providers/reader_provider.dart';

void main() {
  group('ReaderSettingsNotifier', () {
    late ReaderSettingsNotifier notifier;

    setUp(() {
      notifier = ReaderSettingsNotifier();
    });

    test('initial state is default ReadingSettings', () {
      expect(notifier.state.fontSize, 18);
      expect(notifier.state.lineHeight, 1.8);
      expect(notifier.state.letterSpacing, 0.0);
      expect(notifier.state.margin, 16);
      expect(notifier.state.fontFamily, 'system');
      expect(notifier.state.theme, 'white');
      expect(notifier.state.readingMode, 'scroll');
      expect(notifier.state.brightness, 100);
      expect(notifier.state.keepScreenOn, isTrue);
      expect(notifier.state.autoChapter, isTrue);
    });

    test('updateFontSize changes font size', () {
      notifier.updateFontSize(24);

      expect(notifier.state.fontSize, 24);
    });

    test('updateFontSize clamps to minimum 12', () {
      notifier.updateFontSize(5);

      expect(notifier.state.fontSize, 12);
    });

    test('updateFontSize clamps to maximum 36', () {
      notifier.updateFontSize(50);

      expect(notifier.state.fontSize, 36);
    });

    test('updateTheme changes theme', () {
      notifier.updateTheme('dark');

      expect(notifier.state.theme, 'dark');
    });

    test('updateLineHeight changes line height', () {
      notifier.updateLineHeight(2.0);

      expect(notifier.state.lineHeight, 2.0);
    });

    test('updateLineHeight clamps to minimum 1.2', () {
      notifier.updateLineHeight(0.5);

      expect(notifier.state.lineHeight, 1.2);
    });

    test('updateLineHeight clamps to maximum 3.0', () {
      notifier.updateLineHeight(5.0);

      expect(notifier.state.lineHeight, 3.0);
    });

    test('updateReadingMode changes mode', () {
      notifier.updateReadingMode('paged');

      expect(notifier.state.readingMode, 'paged');
    });
  });
}
