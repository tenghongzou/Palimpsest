import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/pagination/paged_notifier.dart';
import '../../data/user_repository.dart';
import '../../domain/entities/reading_stats.dart';

final readingStatsProvider = FutureProvider.autoDispose.family<ReadingStats, String>((ref, period) async {
  return ref.read(userRepositoryProvider).getReadingStats(period: period);
});

final readingHistoryProvider =
    StateNotifierProvider.autoDispose<PagedNotifier<ReadingHistoryEntry>, PagedState<ReadingHistoryEntry>>((ref) {
  final repo = ref.read(userRepositoryProvider);
  return PagedNotifier((page) => repo.getReadingHistory(page: page));
});
