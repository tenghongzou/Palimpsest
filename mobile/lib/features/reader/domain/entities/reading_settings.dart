class ReadingSettings {
  /// Reader themes accepted by the API (`ReadingSettings.theme`).
  static const themes = ['white', 'sepia', 'green', 'dark', 'black'];

  /// Page-turn animations this app offers in page mode. The API also accepts
  /// `curl`, which this app does not draw (see [effectivePageAnimation]).
  static const pageAnimations = ['none', 'slide', 'cover'];

  final int fontSize;
  final double lineHeight;
  final double letterSpacing;
  final int margin;
  final String fontFamily;
  final String theme;
  final String readingMode;

  /// `ReadingSettings.page_animation` as stored (none, slide, cover or curl).
  /// A `curl` chosen on another client is kept as is, so saving other
  /// settings from here does not overwrite it.
  final String pageAnimation;
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
    this.pageAnimation = 'slide',
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
    String? pageAnimation,
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
      pageAnimation: pageAnimation ?? this.pageAnimation,
      brightness: brightness ?? this.brightness,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      autoChapter: autoChapter ?? this.autoChapter,
    );
  }

  /// Maps legacy or unknown theme names onto the API's themes.
  static String normalizeTheme(String? theme) {
    if (theme == 'yellow') return 'sepia';
    return themes.contains(theme) ? theme! : 'white';
  }

  /// The animation page mode actually uses: `curl` (not drawn by this app)
  /// falls back to `cover`, its closest look; unknown values to `slide`.
  String get effectivePageAnimation {
    if (pageAnimation == 'curl') return 'cover';
    return pageAnimations.contains(pageAnimation) ? pageAnimation : 'slide';
  }

  /// Parses `GET /users/me/reading-settings` data.
  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    const d = ReadingSettings();
    return ReadingSettings(
      fontSize: (json['font_size'] as num?)?.toInt() ?? d.fontSize,
      lineHeight: (json['line_height'] as num?)?.toDouble() ?? d.lineHeight,
      letterSpacing: (json['letter_spacing'] as num?)?.toDouble() ?? d.letterSpacing,
      margin: (json['margin'] as num?)?.toInt() ?? d.margin,
      fontFamily: json['font_family'] as String? ?? d.fontFamily,
      theme: normalizeTheme(json['theme'] as String?),
      readingMode: json['reading_mode'] as String? ?? d.readingMode,
      pageAnimation: json['page_animation'] as String? ?? d.pageAnimation,
      brightness: (json['brightness'] as num?)?.toInt() ?? d.brightness,
      keepScreenOn: json['keep_screen_on'] as bool? ?? d.keepScreenOn,
      autoChapter: json['auto_chapter'] as bool? ?? d.autoChapter,
    );
  }

  /// The full body for `PUT /users/me/reading-settings`, clamped to the
  /// ranges the API accepts (PUT replaces every field, except that an omitted
  /// `page_animation` keeps the stored one: a `curl` this app cannot show is
  /// not sent back).
  Map<String, dynamic> toApiJson() => {
        'font_size': fontSize.clamp(12, 36),
        'line_height': lineHeight.clamp(1.2, 3.0),
        'letter_spacing': letterSpacing.clamp(0.0, 5.0),
        'margin': margin.clamp(0, 64),
        'font_family': fontFamily.length > 50 ? fontFamily.substring(0, 50) : fontFamily,
        'theme': normalizeTheme(theme),
        'reading_mode': readingMode == 'page' || readingMode == 'paged' ? 'page' : 'scroll',
        if (pageAnimations.contains(pageAnimation)) 'page_animation': pageAnimation,
        'brightness': brightness.clamp(10, 100),
        'keep_screen_on': keepScreenOn,
        'auto_chapter': autoChapter,
      };
}
