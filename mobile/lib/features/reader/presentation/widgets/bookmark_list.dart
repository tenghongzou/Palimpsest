import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/bookmark_repository.dart';
import '../../domain/entities/bookmark.dart';
import '../providers/chapter_provider.dart';
import '../../../../core/l10n/l10n.dart';

/// Bookmarks of a novel (or all when [novelId] is null), read from local
/// storage and synced with the server when shown.
class BookmarkList extends ConsumerStatefulWidget {
  final String? novelId;
  final ValueChanged<Bookmark> onOpen;
  final ScrollController? scrollController;

  const BookmarkList({super.key, this.novelId, required this.onOpen, this.scrollController});

  @override
  ConsumerState<BookmarkList> createState() => _BookmarkListState();
}

class _BookmarkListState extends ConsumerState<BookmarkList> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(bookmarkRepositoryProvider).syncNow();
      } catch (_) {}
      if (mounted) ref.invalidate(bookmarksProvider(widget.novelId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider(widget.novelId));
    return bookmarks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(context.l10n.bookmarksLoadFailed(describeError(e, context.l10n)))),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(icon: Icons.bookmark_border, message: context.l10n.bookmarksEmpty);
        }
        return ListView.separated(
          controller: widget.scrollController,
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final b = list[i];
            return ListTile(
              leading: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
              title: Text(b.chapterTitle ?? context.l10n.bookmarkChapterFallback, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  context.l10n.commentParagraphLabel(b.paragraphIndex + 1),
                  formatRelative(b.createdAt.toLocal(), context.l10n),
                  if (!b.isSynced) context.l10n.bookmarkNotSynced,
                ].join(' · ') +
                    (b.note == null ? '' : '\n${b.note}'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: b.note != null,
              onTap: () => widget.onOpen(b),
              trailing: PopupMenuButton<String>(
                tooltip: context.l10n.bookmarkOptions,
                onSelected: (action) => action == 'note' ? _editNote(b) : _delete(b),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'note', child: Text(context.l10n.bookmarkEditNote)),
                  PopupMenuItem(value: 'delete', child: Text(context.l10n.commonDelete)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _delete(Bookmark b) async {
    await ref.read(bookmarkRepositoryProvider).delete(b.id);
    ref.invalidate(bookmarksProvider(widget.novelId));
    if (mounted) showSnack(context, context.l10n.bookmarkDeleted);
  }

  Future<void> _editNote(Bookmark b) async {
    final controller = TextEditingController(text: b.note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.bookmarkNote),
        content: TextField(controller: controller, maxLength: 500, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.l10n.commonSave)),
        ],
      ),
    );
    if (note == null) return;
    await ref.read(bookmarkRepositoryProvider).updateNote(b.id, note);
    ref.invalidate(bookmarksProvider(widget.novelId));
  }
}
