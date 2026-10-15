import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/reading_settings.dart';
import '../providers/reader_provider.dart';
import '../../../../core/l10n/l10n.dart';

String _themeLabel(String theme, AppLocalizations l) => switch (theme) {
      'white' => l.themeWhite,
      'sepia' => l.themeSepia,
      'green' => l.themeGreen,
      'dark' => l.themeDark,
      'black' => l.themeBlack,
      _ => theme,
    };

/// Reader preference controls. [compact] shows only what the in-reader panel
/// needs; the settings page shows everything.
class ReadingSettingsPanel extends ConsumerWidget {
  final bool compact;

  const ReadingSettingsPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final l = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _slider(l.settingFontSize, settings.fontSize.toDouble(), 12, 36, 24, '${settings.fontSize}',
            (v) => notifier.updateFontSize(v.round())),
        _slider(l.settingLineHeight, settings.lineHeight, 1.2, 3.0, 18, settings.lineHeight.toStringAsFixed(1),
            (v) => notifier.updateLineHeight(double.parse(v.toStringAsFixed(1)))),
        if (!compact) ...[
          _slider(l.settingLetterSpacing, settings.letterSpacing.clamp(0.0, 5.0), 0, 5, 10, settings.letterSpacing.toStringAsFixed(1),
              (v) => notifier.updateLetterSpacing(double.parse(v.toStringAsFixed(1)))),
          _slider(l.settingMargin, settings.margin.clamp(0, 64).toDouble(), 0, 64, 16, '${settings.margin}',
              (v) => notifier.updateMargin(v.round())),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 64, child: Text(l.settingReadingMode)),
              Expanded(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'scroll', label: Text(l.settingModeScroll)),
                    ButtonSegment(value: 'page', label: Text(l.settingModePage)),
                  ],
                  selected: {settings.readingMode == 'page' ? 'page' : 'scroll'},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => notifier.updateReadingMode(v.first),
                ),
              ),
            ],
          ),
        ),
        // In the reader only while it matters; always on the settings page.
        if (!compact || settings.readingMode == 'page')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 64, child: Text(l.settingPageAnimation)),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'none', label: Text(l.settingAnimationNone)),
                      ButtonSegment(value: 'slide', label: Text(l.settingAnimationSlide)),
                      ButtonSegment(value: 'cover', label: Text(l.settingAnimationCover)),
                      ButtonSegment(value: 'curl', label: Text(l.settingAnimationCurl)),
                    ],
                    selected: {settings.effectivePageAnimation},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => notifier.updatePageAnimation(v.first),
                  ),
                ),
              ],
            ),
          ),
        _slider(l.settingBrightness, settings.brightness.clamp(10, 100).toDouble(), 10, 100, 9, '${settings.brightness}%',
            (v) => notifier.updateBrightness(v.round())),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ReadingSettings.themes.map((t) {
            final c = AppTheme.readerThemes[t]!;
            final selected = settings.theme == t;
            return Tooltip(
              message: _themeLabel(t, l),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                onTap: () => notifier.updateTheme(t),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: Center(child: Text(l.settingThemeSample, style: TextStyle(color: c.text, fontSize: 14))),
                ),
              ),
              ),
            );
          }).toList(),
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(l.settingKeepScreenOn),
            value: settings.keepScreenOn,
            onChanged: notifier.updateKeepScreenOn,
          ),
          SwitchListTile(
            title: Text(l.settingAutoChapter),
            value: settings.autoChapter,
            onChanged: notifier.updateAutoChapter,
          ),
        ],
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max, int divisions, String display,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
        ),
        SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
      ],
    );
  }
}
