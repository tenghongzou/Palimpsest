import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../reader/presentation/providers/reader_provider.dart';
import '../../../reader/presentation/widgets/reading_settings_panel.dart';
import '../../../../core/l10n/l10n.dart';

class ReadingSettingsPage extends ConsumerStatefulWidget {
  const ReadingSettingsPage({super.key});

  @override
  ConsumerState<ReadingSettingsPage> createState() => _ReadingSettingsPageState();
}

class _ReadingSettingsPageState extends ConsumerState<ReadingSettingsPage> {
  @override
  void initState() {
    super.initState();
    // Pick up changes made on other devices.
    Future.microtask(() => ref.read(readerSettingsProvider.notifier).syncWithServer());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = AppTheme.readerThemes[settings.theme] ?? AppTheme.readerThemes['white']!;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.readingSettings),
        actions: [
          TextButton(
            onPressed: () => ref.read(readerSettingsProvider.notifier).resetToDefaults(),
            child: Text(context.l10n.readingSettingsReset),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: settings.margin.toDouble(), vertical: 16),
            color: theme.background,
            child: Text(
              '　　${context.l10n.readingSettingsPreview}',
              style: TextStyle(
                color: theme.text,
                fontSize: settings.fontSize.toDouble(),
                height: settings.lineHeight,
                letterSpacing: settings.letterSpacing,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ReadingSettingsPanel(),
        ],
      ),
    );
  }
}
