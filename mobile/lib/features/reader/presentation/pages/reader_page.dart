import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/chapter_provider.dart';
import '../providers/reader_provider.dart';
import '../../domain/entities/reading_settings.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String chapterId;

  const ReaderPage({super.key, required this.chapterId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  bool _showToolbar = false;
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(chapterProvider(widget.chapterId));
    final settings = ref.watch(readerSettingsProvider);
    final theme = AppTheme.readerThemes[settings.theme] ?? AppTheme.readerThemes['white']!;

    return Scaffold(
      backgroundColor: theme.background,
      body: GestureDetector(
        onTap: () => setState(() {
          _showToolbar = !_showToolbar;
          if (!_showToolbar) _showSettings = false;
        }),
        child: chapterAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('載入失敗：$e')),
          data: (chapter) => Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: settings.margin.toDouble() + 16, vertical: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        chapter.title,
                        style: TextStyle(
                          fontSize: settings.fontSize + 4,
                          fontWeight: FontWeight.bold,
                          color: theme.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...chapter.content.split('\n').where((p) => p.trim().isNotEmpty).map(
                      (paragraph) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '　　${paragraph.trim()}',
                          style: TextStyle(
                            fontSize: settings.fontSize.toDouble(),
                            height: settings.lineHeight,
                            letterSpacing: settings.letterSpacing,
                            color: theme.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(onPressed: () {}, child: Text('上一章', style: TextStyle(color: theme.text))),
                        TextButton(onPressed: () {}, child: Text('下一章', style: TextStyle(color: theme.text))),
                      ],
                    ),
                  ],
                ),
              ),
              if (_showToolbar) ...[
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                          Expanded(child: Text(chapter.title, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(icon: const Icon(Icons.list), onPressed: () {}),
                              IconButton(
                                icon: const Icon(Icons.settings),
                                onPressed: () => setState(() => _showSettings = !_showSettings),
                              ),
                              IconButton(icon: const Icon(Icons.bookmark_outline), onPressed: () {}),
                              IconButton(icon: const Icon(Icons.translate), onPressed: () {}),
                            ],
                          ),
                          if (_showSettings) _buildSettingsPanel(settings),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(ReadingSettings settings) {
    final notifier = ref.read(readerSettingsProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text('字體大小'),
              Expanded(
                child: Slider(
                  value: settings.fontSize.toDouble(),
                  min: 12, max: 32, divisions: 20,
                  onChanged: (v) => notifier.updateFontSize(v.round()),
                ),
              ),
              Text('${settings.fontSize}'),
            ],
          ),
          Row(
            children: [
              const Text('行高'),
              Expanded(
                child: Slider(
                  value: settings.lineHeight,
                  min: 1.2, max: 3.0, divisions: 18,
                  onChanged: (v) => notifier.updateLineHeight(v),
                ),
              ),
              Text(settings.lineHeight.toStringAsFixed(1)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['white', 'yellow', 'green', 'dark', 'black'].map((t) {
              final c = AppTheme.readerThemes[t]!;
              return GestureDetector(
                onTap: () => notifier.updateTheme(t),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: settings.theme == t ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                      width: settings.theme == t ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
