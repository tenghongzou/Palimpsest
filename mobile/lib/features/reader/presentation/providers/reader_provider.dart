import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/reading_settings.dart';

final readerSettingsProvider = StateNotifierProvider<ReaderSettingsNotifier, ReadingSettings>((ref) {
  return ReaderSettingsNotifier();
});

class ReaderSettingsNotifier extends StateNotifier<ReadingSettings> {
  ReaderSettingsNotifier() : super(const ReadingSettings());

  /// Load persisted settings from local SQLite on app startup.
  Future<void> loadFromLocal() async {
    try {
      final data = await DatabaseHelper.loadReadingSettings();
      if (data != null) {
        state = ReadingSettings(
          fontSize: data['font_size'] as int? ?? 18,
          lineHeight: (data['line_height'] as num?)?.toDouble() ?? 1.8,
          letterSpacing: (data['letter_spacing'] as num?)?.toDouble() ?? 0.0,
          margin: data['margin'] as int? ?? 16,
          fontFamily: data['font_family'] as String? ?? 'system',
          theme: data['theme'] as String? ?? 'white',
          readingMode: data['reading_mode'] as String? ?? 'scroll',
          brightness: data['brightness'] as int? ?? 100,
          keepScreenOn: (data['keep_screen_on'] as int? ?? 1) == 1,
          autoChapter: (data['auto_chapter'] as int? ?? 1) == 1,
        );
      }
    } catch (_) {
      // If DB read fails, keep defaults
    }
  }

  void updateFontSize(int size) {
    state = state.copyWith(fontSize: size.clamp(12, 36));
    _persist();
  }

  void updateTheme(String theme) {
    state = state.copyWith(theme: theme);
    _persist();
  }

  void updateLineHeight(double height) {
    state = state.copyWith(lineHeight: height.clamp(1.2, 3.0));
    _persist();
  }

  void updateReadingMode(String mode) {
    state = state.copyWith(readingMode: mode);
    _persist();
  }

  void updateLetterSpacing(double spacing) {
    state = state.copyWith(letterSpacing: spacing.clamp(-1.0, 5.0));
    _persist();
  }

  void updateMargin(int margin) {
    state = state.copyWith(margin: margin.clamp(0, 48));
    _persist();
  }

  void updateFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
    _persist();
  }

  void updateBrightness(int brightness) {
    state = state.copyWith(brightness: brightness.clamp(0, 100));
    _persist();
  }

  void updateKeepScreenOn(bool keep) {
    state = state.copyWith(keepScreenOn: keep);
    _persist();
  }

  void updateAutoChapter(bool auto) {
    state = state.copyWith(autoChapter: auto);
    _persist();
  }

  void resetToDefaults() {
    state = const ReadingSettings();
    _persist();
  }

  Future<void> _persist() async {
    try {
      await DatabaseHelper.saveReadingSettings(
        fontSize: state.fontSize,
        lineHeight: state.lineHeight,
        letterSpacing: state.letterSpacing,
        margin: state.margin,
        fontFamily: state.fontFamily,
        theme: state.theme,
        readingMode: state.readingMode,
        brightness: state.brightness,
        keepScreenOn: state.keepScreenOn,
        autoChapter: state.autoChapter,
      );
    } catch (_) {
      // Non-critical: settings will be re-persisted on next change
    }
  }
}
