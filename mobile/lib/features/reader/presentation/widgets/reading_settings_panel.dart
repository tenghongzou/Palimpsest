import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/reading_settings.dart';
import '../providers/reader_provider.dart';

const _themeLabels = {'white': '白', 'sepia': '米黃', 'green': '護眼綠', 'dark': '夜間', 'black': '純黑'};

/// Reader preference controls. [compact] shows only what the in-reader panel
/// needs; the settings page shows everything.
class ReadingSettingsPanel extends ConsumerWidget {
  final bool compact;

  const ReadingSettingsPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _slider('字體大小', settings.fontSize.toDouble(), 12, 36, 24, '${settings.fontSize}',
            (v) => notifier.updateFontSize(v.round())),
        _slider('行高', settings.lineHeight, 1.2, 3.0, 18, settings.lineHeight.toStringAsFixed(1),
            (v) => notifier.updateLineHeight(double.parse(v.toStringAsFixed(1)))),
        if (!compact) ...[
          _slider('字距', settings.letterSpacing.clamp(0.0, 5.0), 0, 5, 10, settings.letterSpacing.toStringAsFixed(1),
              (v) => notifier.updateLetterSpacing(double.parse(v.toStringAsFixed(1)))),
          _slider('邊距', settings.margin.clamp(0, 64).toDouble(), 0, 64, 16, '${settings.margin}',
              (v) => notifier.updateMargin(v.round())),
        ],
        _slider('亮度', settings.brightness.clamp(10, 100).toDouble(), 10, 100, 9, '${settings.brightness}%',
            (v) => notifier.updateBrightness(v.round())),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ReadingSettings.themes.map((t) {
            final c = AppTheme.readerThemes[t]!;
            final selected = settings.theme == t;
            return Tooltip(
              message: _themeLabels[t] ?? t,
              child: GestureDetector(
                onTap: () => notifier.updateTheme(t),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: Center(child: Text('文', style: TextStyle(color: c.text, fontSize: 14))),
                ),
              ),
            );
          }).toList(),
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('閱讀時保持螢幕開啟'),
            value: settings.keepScreenOn,
            onChanged: notifier.updateKeepScreenOn,
          ),
          SwitchListTile(
            title: const Text('讀完自動跳至下一章'),
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
