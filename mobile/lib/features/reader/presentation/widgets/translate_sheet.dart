import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/reader_repository.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/chapter_translation.dart';
import '../../../../core/l10n/l10n.dart';

/// Shows the translation sheet; resolves to a translation the user chose to
/// display in the reader.
/// [dark] follows the reader theme, so the sheet is not white at night.
Future<ChapterTranslation?> showTranslateSheet(BuildContext context, Chapter chapter, {bool dark = false}) {
  Widget sheet(BuildContext _) => FractionallySizedBox(heightFactor: 0.85, child: TranslateSheet(chapter: chapter));
  return showModalBottomSheet<ChapterTranslation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: dark ? AppTheme.dark.colorScheme.surfaceContainerLow : null,
    builder: dark ? (c) => Theme(data: AppTheme.dark, child: Builder(builder: sheet)) : sheet,
  );
}

/// Friendly message for a failed translation request.
String translationErrorMessage(Object error, String targetLang, AppLocalizations l) {
  final status = httpStatus(error);
  if (status == 503 || apiErrorCode(error) == ApiErrorCode.translationUnavailable) {
    return targetLang == 'en' ? l.translateEnglishUnavailable : l.translateUnavailable;
  }
  if (status == 401) return l.translateSignIn;
  if (status == 429) return l.translateRateLimited;
  if (isNetworkError(error)) return l.translateNetwork;
  return l.translateFailed(describeError(error, l));
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
      if (mounted) setState(() => _error = translationErrorMessage(e, lang, context.l10n));
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
              Text(context.l10n.translateTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                child: Text(context.l10n.translateShowInReader),
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
          Text(context.l10n.translateSignIn),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/login');
            },
            child: Text(context.l10n.authLogin),
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
    if (result == null) return Center(child: Text(context.l10n.translatePickLanguage));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text(result.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        if (result.isCached)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(context.l10n.translateCached, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        const SizedBox(height: 12),
        Text(result.content, style: const TextStyle(height: 1.7)),
      ],
    );
  }
}
