import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/community_repository.dart';
import '../../domain/entities/community.dart';
import 'report_dialog.dart';
import '../../../../core/l10n/l10n.dart';

/// Which comments a sheet lists: a chapter's, or one paragraph's.
typedef CommentsQuery = ({String chapterId, int? paragraph});

final commentsProvider = StateNotifierProvider.autoDispose
    .family<PagedNotifier<Comment>, PagedState<Comment>, CommentsQuery>((ref, query) {
  final repo = ref.read(communityRepositoryProvider);
  return PagedNotifier((page) => repo.getComments(query.chapterId, page: page, paragraphIndex: query.paragraph));
});

/// Top-level comment count per paragraph of a chapter. Failures (e.g.
/// offline) give no counts, so the reader simply shows no bubbles.
final paragraphCountsProvider = FutureProvider.autoDispose.family<Map<int, int>, String>((ref, chapterId) async {
  try {
    return await ref.read(communityRepositoryProvider).getParagraphCounts(chapterId);
  } catch (_) {
    return const {};
  }
});

/// The thread holding a comment id, or null when it no longer exists (404).
/// Other failures (e.g. offline) are errors.
final commentThreadProvider = FutureProvider.autoDispose.family<Comment?, String>((ref, commentId) async {
  try {
    return await ref.read(communityRepositoryProvider).getCommentThread(commentId);
  } catch (e) {
    if (httpStatus(e) == 404) return null;
    rethrow;
  }
});

/// Opens the comments of a chapter or, with [paragraphIndex], of one of its
/// paragraphs. [focusCommentId] (a thread or reply) is pinned at the top,
/// e.g. when opened from a reply notification. [dark] follows the reader theme.
Future<void> showCommentsSheet(
  BuildContext context,
  String chapterId, {
  int? paragraphIndex,
  String? paragraphText,
  String? focusCommentId,
  bool dark = false,
}) {
  Widget sheet(BuildContext _) => FractionallySizedBox(
        heightFactor: paragraphIndex == null ? 0.85 : 0.7,
        child: CommentsSheet(
          chapterId: chapterId,
          paragraphIndex: paragraphIndex,
          paragraphText: paragraphText,
          focusCommentId: focusCommentId,
        ),
      );
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: dark ? AppTheme.dark.colorScheme.surfaceContainerLow : null,
    builder: dark ? (c) => Theme(data: AppTheme.dark, child: Builder(builder: sheet)) : sheet,
  );
}

/// Chapter or paragraph comments: list with replies, post, reply, like,
/// delete and report.
class CommentsSheet extends ConsumerStatefulWidget {
  final String chapterId;

  /// Only this paragraph's comments; new comments are posted on it.
  final int? paragraphIndex;
  final String? paragraphText;
  final String? focusCommentId;

  const CommentsSheet({
    super.key,
    required this.chapterId,
    this.paragraphIndex,
    this.paragraphText,
    this.focusCommentId,
  });

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _input = TextEditingController();

  /// The sheet's own messenger: snack bars shown on the page's messenger
  /// would sit behind the sheet.
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Comment? _replyTo;
  bool _posting = false;

  CommentsQuery get _query => (chapterId: widget.chapterId, paragraph: widget.paragraphIndex);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool _requireLogin() {
    if (ref.read(authStateProvider).valueOrNull != null) return true;
    showSnack(context, context.l10n.errorUnauthorized);
    Navigator.of(context).pop();
    context.push('/login');
    return false;
  }

  /// Shows [message] inside the sheet, above its input.
  void _snack(String message) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Paragraph bubbles count top-level comments, so refresh them after a change.
  void _countsChanged() => ref.invalidate(paragraphCountsProvider(widget.chapterId));

  /// Re-reads the pinned thread after a change to it.
  void _threadChanged() {
    final id = widget.focusCommentId;
    if (id != null) ref.invalidate(commentThreadProvider(id));
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (text.isEmpty || !_requireLogin()) return;
    setState(() => _posting = true);
    try {
      final parent = _replyTo;
      final created = await ref.read(communityRepositoryProvider).createComment(
            widget.chapterId,
            text,
            parentId: parent?.id,
            paragraphIndex: parent == null ? widget.paragraphIndex : null,
          );
      _input.clear();
      if (mounted) setState(() => _replyTo = null);
      // Held for moderation: not public yet, so the list, the pinned thread
      // and the paragraph counts stay as they are.
      if (created.status.isHeld) {
        if (mounted) _snack(context.l10n.moderationPendingSubmitted);
        return;
      }
      if (parent == null) _countsChanged();
      _threadChanged();
      await ref.read(commentsProvider(_query).notifier).refresh();
    } catch (e) {
      if (mounted) _snack(context.l10n.commentPostFailed(describeError(e, context.l10n)));
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
      ref.read(commentsProvider(_query).notifier).updateItems((items) => items.map(apply).toList());
      _threadChanged();
    } catch (e) {
      if (mounted) _snack(describeError(e, context.l10n));
    }
  }

  Future<void> _delete(Comment c) async {
    try {
      await ref.read(communityRepositoryProvider).deleteComment(c.id);
      if (c.parentId == null) _countsChanged();
      _threadChanged();
      await ref.read(commentsProvider(_query).notifier).refresh();
    } catch (e) {
      if (mounted) _snack(describeError(e, context.l10n));
    }
  }

  Widget _thread(Comment c, String? userId) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentTile(
            comment: c,
            isMine: c.userId == userId,
            paragraphLabel: widget.paragraphIndex == null && c.paragraphIndex != null
                ? context.l10n.commentParagraphLabel(c.paragraphIndex! + 1)
                : null,
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
        ],
      );

  /// The focused thread (GET /comments/{id}) pinned above the list.
  Widget? _focusHeader(String? userId) {
    final id = widget.focusCommentId;
    if (id == null) return null;
    final result = ref.watch(commentThreadProvider(id));
    final subtle = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    // Still loading, or unreachable (the list below shows the error).
    if (!result.hasValue) return null;
    final thread = result.value;
    if (thread == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(context.l10n.commentThreadGone, style: subtle),
      );
    }
    return Container(
      key: const ValueKey('focused-thread'),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(context.l10n.commentRepliedThread, style: subtle)),
          _thread(thread, userId),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentsProvider(_query));
    final notifier = ref.read(commentsProvider(_query).notifier);
    final userId = ref.watch(authStateProvider).valueOrNull?.id;
    final paragraph = widget.paragraphIndex;
    final quote = widget.paragraphText;
    final scheme = Theme.of(context).colorScheme;

    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The input pads itself above the keyboard.
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Text(paragraph == null ? context.l10n.chapterComments : context.l10n.paragraphComments(paragraph + 1),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(tooltip: context.l10n.commonClose, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            if (paragraph != null && quote != null && quote.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: scheme.outlineVariant, width: 3))),
                child: Text(
                  quote,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: PagedListView<Comment>(
                state: state,
                onLoadMore: notifier.loadMore,
                onRefresh: notifier.refresh,
                header: _focusHeader(userId),
                empty: Text(paragraph == null ? context.l10n.commentsEmpty : context.l10n.commentsParagraphEmpty),
                itemBuilder: (context, c, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_thread(c, userId), const Divider(height: 1)],
                ),
              ),
            ),
          ],
        ),
        // Here rather than in the body so snack bars show above the input.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Container(
                color: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(context.l10n.commentReplyingTo(_replyTo!.user?.displayName ?? ''),
                          overflow: TextOverflow.ellipsis),
                    ),
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
                        decoration: InputDecoration(
                          hintText: paragraph == null || _replyTo != null
                              ? context.l10n.commentHint
                              : context.l10n.commentParagraphHint,
                          counterText: '',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.commentSend,
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
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isMine;

  /// e.g. "第 3 段" for a paragraph comment shown among the chapter's.
  final String? paragraphLabel;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const _CommentTile({
    required this.comment,
    required this.isMine,
    this.paragraphLabel,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final user = comment.user?.displayName ?? '';
    final name = user.isEmpty ? context.l10n.anonymousReader : user;
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
                Text(
                  [name, formatRelative(comment.createdAt, context.l10n), if (paragraphLabel != null) paragraphLabel!].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(comment.content),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onLike,
                      icon: Icon(comment.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16),
                      label: Text('${comment.likeCount}'),
                    ),
                    TextButton(onPressed: onReply, child: Text(context.l10n.commentReply)),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: context.l10n.commonMore,
                      icon: const Icon(Icons.more_horiz, size: 18),
                      onSelected: (v) => v == 'delete' ? onDelete() : onReport(),
                      itemBuilder: (_) => [
                        if (isMine) PopupMenuItem(value: 'delete', child: Text(context.l10n.commonDelete)),
                        if (!isMine) PopupMenuItem(value: 'report', child: Text(context.l10n.report)),
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
