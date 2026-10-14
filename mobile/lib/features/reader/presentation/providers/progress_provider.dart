import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/network/api_client.dart';
import '../../../profile/data/user_repository.dart';

/// Where to continue reading a novel.
class ResumePoint {
  final String chapterId;
  final int paragraphIndex;
  final DateTime? readAt;

  const ResumePoint({required this.chapterId, this.paragraphIndex = 0, this.readAt});

  String get location => paragraphIndex > 0 ? '/read/$chapterId?p=$paragraphIndex' : '/read/$chapterId';
}

/// The most recent reading position of a novel, from the device or (when
/// signed in) the server, whichever was read last.
final resumePointProvider = FutureProvider.autoDispose.family<ResumePoint?, String>((ref, novelId) async {
  ResumePoint? local;
  try {
    final row = await (await ref.read(offlineStoreProvider)()).getProgress(novelId);
    if (row != null) {
      local = ResumePoint(
        chapterId: row['chapter_id'] as String,
        paragraphIndex: row['paragraph_index'] as int? ?? 0,
        readAt: DateTime.tryParse(row['read_at'] as String? ?? ''),
      );
    }
  } catch (_) {}

  ResumePoint? remote;
  if (ref.read(apiClientProvider).hasAccessToken) {
    try {
      final p = await ref.read(userRepositoryProvider).getProgress(novelId);
      if (p != null) remote = ResumePoint(chapterId: p.chapterId, paragraphIndex: p.paragraphIndex, readAt: p.readAt);
    } catch (_) {}
  }

  if (local == null) return remote;
  if (remote == null) return local;
  final localAt = local.readAt;
  final remoteAt = remote.readAt;
  if (localAt == null) return remote;
  if (remoteAt == null) return local;
  return remoteAt.isAfter(localAt) ? remote : local;
});
