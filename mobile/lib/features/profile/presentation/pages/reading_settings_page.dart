import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../reader/presentation/providers/reader_provider.dart';
import '../../../reader/presentation/widgets/reading_settings_panel.dart';

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
        title: const Text('閱讀設定'),
        actions: [
          TextButton(
            onPressed: () => ref.read(readerSettingsProvider.notifier).resetToDefaults(),
            child: const Text('恢復預設'),
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
              '　　海霧終年不散的港口，燈塔看守人每晚都會收到一封沒有寄件人的信。',
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
