import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/reader_repository.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/chapter_translation.dart';

/// Shows the translation sheet; resolves to a translation the user chose to
/// display in the reader.
Future<ChapterTranslation?> showTranslateSheet(BuildContext context, Chapter chapter) {
  return showModalBottomSheet<ChapterTranslation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: TranslateSheet(chapter: chapter)),
  );
}

/// Friendly message for a failed translation request.
String translationErrorMessage(Object error, String targetLang) {
  final status = httpStatus(error);
  if (status == 503 || apiErrorCode(error) == ApiErrorCode.translationUnavailable) {
    return targetLang == 'en' ? '英文翻譯服務目前尚未開放，請稍後再試' : '翻譯服務暫時無法使用，請稍後再試';
  }
  if (status == 401) return '請先登入才能使用翻譯';
  if (status == 429) return '翻譯請求過於頻繁（每分鐘最多 20 次），請稍後再試';
  if (isNetworkError(error)) return '網路連線失敗，無法翻譯';
  return '翻譯失敗：${describeError(error)}';
}

class TranslateSheet extends ConsumerStatefulWidget {
  final Chapter chapter;

  const TranslateSheet({super.key, required this.chapter});

  @override
  ConsumerState<TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends ConsumerState<TranslateSheet> {
  String? _lang;
  bool _loading = false;
  ChapterTranslation? _result;
  String? _error;

  Future<void> _translate(String lang) async {
    setState(() {
      _lang = lang;
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await ref
          .read(readerRepositoryProvider)
          .translateChapter(widget.chapter.id, lang, fallbackTitle: widget.chapter.title);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = translationErrorMessage(e, lang));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text('翻譯本章', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: translationLanguages.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _lang == e.key,
                      onSelected: !signedIn || _loading ? null : (_) => _translate(e.key),
                    ))
                .toList(),
          ),
        ),
        const Divider(),
        Expanded(child: _body(signedIn)),
        if (_result != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _result),
                child: const Text('在閱讀器中顯示譯文'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _body(bool signedIn) {
    if (!signedIn) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('請先登入才能使用翻譯'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/login');
            },
            child: const Text('登入'),
          ),
        ]),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.translate, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    final result = _result;
    if (result == null) return const Center(child: Text('選擇要翻譯成的語言'));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text(result.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        if (result.isCached)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('（快取的譯文）', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        const SizedBox(height: 12),
        Text(result.content, style: const TextStyle(height: 1.7)),
      ],
    );
  }
}
