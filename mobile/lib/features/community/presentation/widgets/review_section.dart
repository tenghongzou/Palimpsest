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

final reviewsProvider = StateNotifierProvider.autoDispose
    .family<PagedNotifier<Review>, PagedState<Review>, String>((ref, novelId) {
  final repo = ref.read(communityRepositoryProvider);
  return PagedNotifier((page) => repo.getReviews(novelId, page: page));
});

/// Reviews of a novel for its detail page: list, write or edit your own,
/// like, delete and report.
class ReviewSection extends ConsumerWidget {
  final String novelId;

  const ReviewSection({super.key, required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewsProvider(novelId));
    final notifier = ref.read(reviewsProvider(novelId).notifier);
    final user = ref.watch(authStateProvider).valueOrNull;
    Review? mine;
    for (final r in state.items) {
      if (r.userId == user?.id) mine = r;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('書評', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              icon: Icon(mine == null ? Icons.rate_review_outlined : Icons.edit_outlined),
              label: Text(mine == null ? '撰寫書評' : '編輯我的書評'),
              onPressed: () => _openEditor(context, ref, mine),
            ),
          ],
        ),
        if (state.isInitialLoading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (state.items.isEmpty && state.error != null)
          Text('書評載入失敗：${describeError(state.error!)}')
        else if (state.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('還沒有書評，成為第一個評論的讀者吧', style: TextStyle(color: Colors.grey)),
          )
        else ...[
          ...state.items.map((r) => _ReviewTile(
                review: r,
                isMine: r.userId == user?.id,
                onLike: () => _toggleLike(context, ref, r),
                onEdit: () => _openEditor(context, ref, r),
                onDelete: () => _delete(context, ref, r),
                onReport: () => showReportDialog(context, ref, targetType: 'review', targetId: r.id),
              )),
          if (state.hasMore)
            Center(
              child: TextButton(
                onPressed: state.isLoading ? null : notifier.loadMore,
                child: Text(state.isLoading ? '載入中…' : '載入更多書評'),
              ),
            ),
        ],
      ],
    );
  }

  bool _requireLogin(BuildContext context, WidgetRef ref) {
    if (ref.read(authStateProvider).valueOrNull != null) return true;
    showSnack(context, '請先登入');
    context.push('/login');
    return false;
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref, Review r) async {
    if (!_requireLogin(context, ref)) return;
    try {
      final result = await ref.read(communityRepositoryProvider).setReviewLike(r.id, !r.likedByMe);
      ref.read(reviewsProvider(novelId).notifier).updateItems((items) => items
          .map((x) => x.id == r.id ? x.withLike(liked: result.liked, likeCount: result.likeCount) : x)
          .toList());
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Review r) async {
    try {
      await ref.read(communityRepositoryProvider).deleteReview(r.id);
      await ref.read(reviewsProvider(novelId).notifier).refresh();
      if (context.mounted) showSnack(context, '已刪除書評');
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e));
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, Review? existing) async {
    if (!_requireLogin(context, ref)) return;
    final input = await showModalBottomSheet<_ReviewInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReviewEditor(existing: existing),
    );
    if (input == null) return;
    final repo = ref.read(communityRepositoryProvider);
    try {
      if (existing == null) {
        await repo.createReview(novelId, title: input.title, content: input.content, rating: input.rating);
      } else {
        await repo.updateReview(existing.id, title: input.title, content: input.content, rating: input.rating);
      }
      await ref.read(reviewsProvider(novelId).notifier).refresh();
      if (context.mounted) showSnack(context, existing == null ? '已發表書評' : '已更新書評');
    } catch (e) {
      if (!context.mounted) return;
      showSnack(context, httpStatus(e) == 409 ? '你已經評論過這本書，可以編輯原本的書評' : '送出失敗：${describeError(e)}');
    }
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const _ReviewTile({
    required this.review,
    required this.isMine,
    required this.onLike,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final userName = review.user?.displayName ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StarRating(rating: review.rating),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${userName.isEmpty ? '讀者' : userName} · ${formatRelative(review.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (review.title.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(review.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 4),
            Text(review.content, maxLines: 6, overflow: TextOverflow.ellipsis),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onLike,
                  icon: Icon(review.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16),
                  label: Text('${review.likeCount}'),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onSelected: (v) {
                    if (v == 'edit') {
                      onEdit();
                    } else if (v == 'delete') {
                      onDelete();
                    } else {
                      onReport();
                    }
                  },
                  itemBuilder: (_) => [
                    if (isMine) const PopupMenuItem(value: 'edit', child: Text('編輯')),
                    if (isMine) const PopupMenuItem(value: 'delete', child: Text('刪除')),
                    if (!isMine) const PopupMenuItem(value: 'report', child: Text('檢舉')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only stars in half steps.
class StarRating extends StatelessWidget {
  final double rating;
  final double size;

  const StarRating({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final color = Colors.amber.shade700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final value = rating - i;
        final icon = value >= 1 ? Icons.star : (value >= 0.5 ? Icons.star_half : Icons.star_border);
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}

class _ReviewInput {
  final String title;
  final String content;
  final double rating;

  const _ReviewInput(this.title, this.content, this.rating);
}

class _ReviewEditor extends StatefulWidget {
  final Review? existing;

  const _ReviewEditor({this.existing});

  @override
  State<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<_ReviewEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _content = TextEditingController(text: widget.existing?.content ?? '');
  late double _rating = widget.existing?.rating ?? 5;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? '撰寫書評' : '編輯書評', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('評分'),
                Expanded(
                  child: Slider(
                    value: _rating,
                    min: 0.5,
                    max: 5,
                    divisions: 9,
                    label: _rating.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ),
                StarRating(rating: _rating),
              ],
            ),
            TextFormField(
              controller: _title,
              maxLength: 200,
              decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? '請輸入標題' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _content,
              maxLength: 10000,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: '內容', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? '請輸入內容' : null,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState?.validate() != true) return;
                Navigator.pop(context, _ReviewInput(_title.text.trim(), _content.text.trim(), _rating));
              },
              child: const Text('送出'),
            ),
          ],
        ),
      ),
    );
  }
}
