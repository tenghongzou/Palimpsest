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
import '../../../../core/l10n/l10n.dart';

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
            Text(context.l10n.reviews, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              icon: Icon(mine == null ? Icons.rate_review_outlined : Icons.edit_outlined),
              label: Text(mine == null ? context.l10n.reviewWrite : context.l10n.reviewEditMine),
              onPressed: () => _openEditor(context, ref, mine),
            ),
          ],
        ),
        if (state.isInitialLoading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (state.items.isEmpty && state.error != null)
          Text(context.l10n.reviewsLoadFailed(describeError(state.error!, context.l10n)))
        else if (state.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(context.l10n.reviewsEmpty, style: const TextStyle(color: Colors.grey)),
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
                child: Text(state.isLoading ? context.l10n.commonLoading : context.l10n.reviewsLoadMore),
              ),
            ),
        ],
      ],
    );
  }

  bool _requireLogin(BuildContext context, WidgetRef ref) {
    if (ref.read(authStateProvider).valueOrNull != null) return true;
    showSnack(context, context.l10n.errorUnauthorized);
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
      if (context.mounted) showSnack(context, describeError(e, context.l10n));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Review r) async {
    try {
      await ref.read(communityRepositoryProvider).deleteReview(r.id);
      await ref.read(reviewsProvider(novelId).notifier).refresh();
      if (context.mounted) showSnack(context, context.l10n.reviewDeleted);
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e, context.l10n));
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
    final notifier = ref.read(reviewsProvider(novelId).notifier);
    try {
      final saved = existing == null
          ? await repo.createReview(novelId, title: input.title, content: input.content, rating: input.rating)
          : await repo.updateReview(existing.id, title: input.title, content: input.content, rating: input.rating);
      if (saved.status.isHeld) {
        // Held for moderation. A new review stays out of the list; an edited
        // one stays in place for its author, marked as under review (the
        // server's list no longer includes it, so no refresh).
        if (existing != null) {
          final held = saved.user == null ? saved.withUser(existing.user) : saved;
          notifier.updateItems((items) => items.map((x) => x.id == existing.id ? held : x).toList());
        }
        if (context.mounted) showSnack(context, context.l10n.moderationPendingSubmitted);
        return;
      }
      await notifier.refresh();
      if (context.mounted) {
        showSnack(context, existing == null ? context.l10n.reviewPublished : context.l10n.reviewUpdated);
      }
    } catch (e) {
      if (!context.mounted) return;
      final l = context.l10n;
      showSnack(context, httpStatus(e) == 409 ? l.reviewAlreadyExists : l.submitFailed(describeError(e, l)));
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
                if (review.status.isHeld) ...[
                  _PendingBadge(key: ValueKey('review-pending-${review.id}')),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    '${userName.isEmpty ? context.l10n.anonymousReader : userName} · '
                    '${formatRelative(review.createdAt, context.l10n)}',
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
                  tooltip: context.l10n.commonMore,
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
                    if (isMine) PopupMenuItem(value: 'edit', child: Text(context.l10n.commonEdit)),
                    if (isMine) PopupMenuItem(value: 'delete', child: Text(context.l10n.commonDelete)),
                    if (!isMine) PopupMenuItem(value: 'report', child: Text(context.l10n.report)),
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

/// Marks the author's own review that awaits moderation.
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(4)),
      child: Text(
        context.l10n.moderationPendingBadge,
        style: TextStyle(fontSize: 11, color: scheme.onTertiaryContainer),
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

  /// Set by the first submit: from then on, field errors update as the
  /// user types instead of lingering until the next submit.
  bool _submitted = false;
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
        autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? context.l10n.reviewWrite : context.l10n.reviewEdit, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(context.l10n.reviewRating),
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
              decoration: InputDecoration(labelText: context.l10n.reviewTitle, border: const OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? context.l10n.reviewTitleRequired : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _content,
              maxLength: 10000,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(labelText: context.l10n.reviewContent, border: const OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? context.l10n.reviewContentRequired : null,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                if (!_submitted) setState(() => _submitted = true);
                if (_formKey.currentState?.validate() != true) return;
                Navigator.pop(context, _ReviewInput(_title.text.trim(), _content.text.trim(), _rating));
              },
              child: Text(context.l10n.commonSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
