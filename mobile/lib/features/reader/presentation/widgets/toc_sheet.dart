import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/chapter_provider.dart';
import '../../../../core/l10n/l10n.dart';

/// Shows the table of contents; resolves to the chosen chapter id.
Future<String?> showTocSheet(BuildContext context, {required String novelId, required String currentChapterId}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: TocSheet(novelId: novelId, currentChapterId: currentChapterId),
    ),
  );
}

class TocSheet extends ConsumerWidget {
  static const _itemExtent = 52.0;

  final String novelId;
  final String currentChapterId;

  const TocSheet({super.key, required this.novelId, required this.currentChapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toc = ref.watch(tocProvider(novelId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text(context.l10n.readerToc, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (toc.valueOrNull?.fromCache ?? false)
                Text(context.l10n.tocOfflineNote, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: toc.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(context.l10n.tocLoadFailed(describeError(e, context.l10n)))),
            data: (toc) {
              final current = toc.entries.indexWhere((c) => c.id == currentChapterId);
              final controller = ScrollController(
                initialScrollOffset: current > 3 ? (current - 3) * _itemExtent : 0,
              );
              return ListView.builder(
                controller: controller,
                itemExtent: _itemExtent,
                itemCount: toc.entries.length,
                itemBuilder: (context, i) {
                  final c = toc.entries[i];
                  final selected = c.id == currentChapterId;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    title: Text(chapterLabel(c.chapterNumber, c.title, context.l10n), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: c.isDownloaded ? const Icon(Icons.download_done, size: 16, color: Colors.green) : null,
                    onTap: () => Navigator.pop(context, c.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
