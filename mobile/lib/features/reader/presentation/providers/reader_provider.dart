import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/reading_settings.dart';

final readerSettingsProvider = StateNotifierProvider<ReaderSettingsNotifier, ReadingSettings>((ref) {
  return ReaderSettingsNotifier();
});

class ReaderSettingsNotifier extends StateNotifier<ReadingSettings> {
  ReaderSettingsNotifier() : super(const ReadingSettings());

  void updateFontSize(int size) {
    state = state.copyWith(fontSize: size.clamp(12, 36));
  }

  void updateTheme(String theme) {
    state = state.copyWith(theme: theme);
  }

  void updateLineHeight(double height) {
    state = state.copyWith(lineHeight: height.clamp(1.2, 3.0));
  }

  void updateReadingMode(String mode) {
    state = state.copyWith(readingMode: mode);
  }

  // TODO: persist settings to local SQLite and sync to server
}
