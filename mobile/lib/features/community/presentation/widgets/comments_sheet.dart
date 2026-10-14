import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/community_repository.dart';
import '../../domain/entities/community.dart';
import 'report_dialog.dart';

final commentsProvider = StateNotifierProvider.autoDispose
    .family<PagedNotifier<Comment>, PagedState<Comment>, String>((ref, chapterId) {
  final repo = ref.read(communityRepositoryProvider);
  return PagedNotifier((page) => repo.getComments(chapterId, page: page));
});

Future<void> showCommentsSheet(BuildContext context, String chapterId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: CommentsSheet(chapterId: chapterId)),
  );
}

/// Chapter comments: list with replies, post, reply, like, delete and report.
class CommentsSheet extends ConsumerStatefulWidget {
  final String chapterId;

  const CommentsSheet({super.key, required this.chapterId});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _input = TextEditingController();
  Comment? _replyTo;
  bool _posting = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool _requireLogin() {
    if (ref.read(authStateProvider).valueOrNull != null) return true;
    showSnack(context, '請先登入');
    Navigator.of(context).pop();
    context.push('/login');
    return false;
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (text.isEmpty || !_requireLogin()) return;
    setState(() => _posting = true);
    try {
      await ref.read(communityRepositoryProvider).createComment(widget.chapterId, text, parentId: _replyTo?.id);
      _input.clear();
      setState(() => _replyTo = null);
      await ref.read(commentsProvider(widget.chapterId).notifier).refresh();
    } catch (e) {
      if (mounted) showSnack(context, '留言失敗：${describeError(e)}');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _toggleLike(Comment c) async {
    if (!_requireLogin()) return;
    try {
      final result = await ref.read(communityRepositoryProvider).setCommentLike(c.id, !c.likedByMe);
      Comment apply(Comment x) => x.id == c.id
          ? x.copyWith(likedByMe: result.liked, likeCount: result.likeCount)
          : x.copyWith(replies: x.replies.map(apply).toList());
      ref.read(commentsProvider(widget.chapterId).notifier).updateItems((items) => items.map(apply).toList());
    } catch (e) {
      if (mounted) showSnack(context, describeError(e));
    }
  }

  Future<void> _delete(Comment c) async {
    try {
      await ref.read(communityRepositoryProvider).deleteComment(c.id);
      await ref.read(commentsProvider(widget.chapterId).notifier).refresh();
    } catch (e) {
      if (mounted) showSnack(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentsProvider(widget.chapterId));
    final notifier = ref.read(commentsProvider(widget.chapterId).notifier);
    final userId = ref.watch(authStateProvider).valueOrNull?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text('本章留言', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: PagedListView<Comment>(
            state: state,
            onLoadMore: notifier.loadMore,
            onRefresh: notifier.refresh,
            empty: const Text('還沒有留言，來搶頭香吧'),
            itemBuilder: (context, c, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommentTile(
                  comment: c,
                  isMine: c.userId == userId,
                  onLike: () => _toggleLike(c),
                  onReply: () => setState(() => _replyTo = c),
                  onDelete: () => _delete(c),
                  onReport: () => showReportDialog(context, ref, targetType: 'comment', targetId: c.id),
                ),
                ...c.replies.map((r) => Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: _CommentTile(
                        comment: r,
                        isMine: r.userId == userId,
                        onLike: () => _toggleLike(r),
                        onReply: () => setState(() => _replyTo = c),
                        onDelete: () => _delete(r),
                        onReport: () => showReportDialog(context, ref, targetType: 'comment', targetId: r.id),
                      ),
                    )),
                const Divider(height: 1),
              ],
            ),
          ),
        ),
        if (_replyTo != null)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text('回覆 ${_replyTo!.user?.displayName ?? ''}', overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyTo = null)),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + MediaQuery.of(context).viewInsets.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '寫下你的想法…',
                      counterText: '',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '送出留言',
                  icon: _posting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  onPressed: _posting ? null : _post,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final user = comment.user?.displayName ?? '';
    final name = user.isEmpty ? '讀者' : user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, child: Text(name.characters.first, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name · ${formatRelative(comment.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(comment.content),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onLike,
                      icon: Icon(comment.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16),
                      label: Text('${comment.likeCount}'),
                    ),
                    TextButton(onPressed: onReply, child: const Text('回覆')),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: '更多',
                      icon: const Icon(Icons.more_horiz, size: 18),
                      onSelected: (v) => v == 'delete' ? onDelete() : onReport(),
                      itemBuilder: (_) => [
                        if (isMine) const PopupMenuItem(value: 'delete', child: Text('刪除')),
                        if (!isMine) const PopupMenuItem(value: 'report', child: Text('檢舉')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
