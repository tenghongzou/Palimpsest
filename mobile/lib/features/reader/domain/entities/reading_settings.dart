class ReadingSettings {
  final int fontSize;
  final double lineHeight;
  final double letterSpacing;
  final int margin;
  final String fontFamily;
  final String theme;
  final String readingMode;
  final int brightness;
  final bool keepScreenOn;
  final bool autoChapter;

  const ReadingSettings({
    this.fontSize = 18,
    this.lineHeight = 1.8,
    this.letterSpacing = 0.0,
    this.margin = 16,
    this.fontFamily = 'system',
    this.theme = 'white',
    this.readingMode = 'scroll',
    this.brightness = 100,
    this.keepScreenOn = true,
    this.autoChapter = true,
  });

  ReadingSettings copyWith({
    int? fontSize,
    double? lineHeight,
    double? letterSpacing,
    int? margin,
    String? fontFamily,
    String? theme,
    String? readingMode,
    int? brightness,
    bool? keepScreenOn,
    bool? autoChapter,
  }) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      margin: margin ?? this.margin,
      fontFamily: fontFamily ?? this.fontFamily,
      theme: theme ?? this.theme,
      readingMode: readingMode ?? this.readingMode,
      brightness: brightness ?? this.brightness,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      autoChapter: autoChapter ?? this.autoChapter,
    );
  }
}
