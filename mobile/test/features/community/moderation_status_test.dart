import 'package:flutter_test/flutter_test.dart';
import 'package:palimpsest/features/community/domain/entities/community.dart';

import '../../support/fake_backend.dart';

const threadId = '33333333-0000-4000-8000-000000000001';
const reviewId = '33333333-0000-4000-8000-000000000002';

void main() {
  group('parsing', () {
    Map<String, dynamic> review(Object? status) => {
          'id': reviewId,
          'user_id': userId,
          'novel_id': novelId,
          'title': 't',
          'content': 'c',
          'rating': 4.5,
          if (status != null) 'status': status,
        };

    test('pending, approved, missing and unknown statuses', () {
      expect(Review.fromJson(review('pending')).status, ModerationStatus.pending);
      expect(Review.fromJson(review('approved')).status, ModerationStatus.approved);
      expect(Review.fromJson(review(null)).status, ModerationStatus.approved);
      expect(Review.fromJson(review('quarantined')).status, ModerationStatus.unknown);
      expect(Review.fromJson(review(3)).status, ModerationStatus.unknown);

      final comment = Comment.fromJson({
        ...commentJson(threadId, '好', replies: [
          {...commentJson('r', '回', parentId: threadId), 'status': 'pending'},
        ]),
        'status': 'hidden',
      });
      expect(comment.status, ModerationStatus.hidden);
      expect(comment.replies.single.status, ModerationStatus.pending);
      expect(Comment.fromJson(commentJson(threadId, '好')).status, ModerationStatus.approved);
    });

    test('held means not public', () {
      expect(ModerationStatus.pending.isHeld, isTrue);
      expect(ModerationStatus.rejected.isHeld, isTrue);
      expect(ModerationStatus.hidden.isHeld, isTrue);
      expect(ModerationStatus.approved.isHeld, isFalse);
      expect(ModerationStatus.unknown.isHeld, isFalse);
    });

    test('likes and users keep the status', () {
      final r = Review.fromJson(review('pending'));
      expect(r.withLike(liked: true, likeCount: 1).status, ModerationStatus.pending);
      expect(r.withUser(null).status, ModerationStatus.pending);
      expect(Comment.fromJson({...commentJson(threadId, '好'), 'status': 'pending'}).copyWith(likeCount: 2).status,
          ModerationStatus.pending);
    });
  });
}
