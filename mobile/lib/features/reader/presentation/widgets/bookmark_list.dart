import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../data/bookmark_repository.dart';
import '../../domain/entities/bookmark.dart';
import '../providers/chapter_provider.dart';

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
      error: (e, _) => Center(child: Text('讀取書籤失敗：$e')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(icon: Icons.bookmark_border, message: '還沒有書籤\n閱讀時點選書籤圖示即可加入');
        }
        return ListView.separated(
          controller: widget.scrollController,
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final b = list[i];
            return ListTile(
              leading: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
              title: Text(b.chapterTitle ?? '章節', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  '第 ${b.paragraphIndex + 1} 段',
                  formatRelative(b.createdAt.toLocal()),
                  if (!b.isSynced) '尚未同步',
                ].join(' · ') +
                    (b.note == null ? '' : '\n${b.note}'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: b.note != null,
              onTap: () => widget.onOpen(b),
              trailing: PopupMenuButton<String>(
                tooltip: '書籤選項',
                onSelected: (action) => action == 'note' ? _editNote(b) : _delete(b),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'note', child: Text('編輯備註')),
                  PopupMenuItem(value: 'delete', child: Text('刪除')),
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
    if (mounted) showSnack(context, '已刪除書籤');
  }

  Future<void> _editNote(Bookmark b) async {
    final controller = TextEditingController(text: b.note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('書籤備註'),
        content: TextField(controller: controller, maxLength: 500, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('儲存')),
        ],
      ),
    );
    if (note == null) return;
    await ref.read(bookmarkRepositoryProvider).updateNote(b.id, note);
    ref.invalidate(bookmarksProvider(widget.novelId));
  }
}
