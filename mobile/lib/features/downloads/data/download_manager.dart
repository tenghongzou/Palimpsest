import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/database/offline_store.dart';
import '../../../core/network/api_error.dart';
import '../../bookstore/domain/entities/novel.dart';
import '../../reader/data/reader_repository.dart';
import '../../reader/domain/entities/chapter.dart';

enum DownloadStatus { queued, running, completed, failed, cancelled }

class DownloadTask {
  final String novelId;
  final String title;
  final int done;
  final int total;
  final DownloadStatus status;
  final String? error;

  const DownloadTask({
    required this.novelId,
    required this.title,
    this.done = 0,
    this.total = 0,
    this.status = DownloadStatus.queued,
    this.error,
  });

  bool get isActive => status == DownloadStatus.queued || status == DownloadStatus.running;
  double get fraction => total == 0 ? 0 : done / total;

  DownloadTask copyWith({int? done, int? total, DownloadStatus? status, String? error}) => DownloadTask(
        novelId: novelId,
        title: title,
        done: done ?? this.done,
        total: total ?? this.total,
        status: status ?? this.status,
        error: error,
      );
}

final downloadManagerProvider = StateNotifierProvider<DownloadManager, Map<String, DownloadTask>>((ref) {
  return DownloadManager(
    reader: ref.read(readerRepositoryProvider),
    store: ref.read(offlineStoreProvider),
  );
});

/// Novels with downloaded chapters; refreshed as downloads progress.
final downloadedNovelsProvider = FutureProvider.autoDispose<List<DownloadedNovel>>((ref) async {
  ref.watch(downloadManagerProvider);
  return (await ref.read(offlineStoreProvider)()).downloadedNovels();
});

/// Downloads whole novels for offline reading, one chapter at a time and one
/// novel at a time. Requests are spaced by [interval] to stay well below the
/// API rate limit (120 requests/min signed in, 60 anonymous); a 429 response
/// pauses for its Retry-After before trying again.
class DownloadManager extends StateNotifier<Map<String, DownloadTask>> {
  static const maxRateLimitRetries = 3;

  final ReaderRepository reader;
  final Future<OfflineStore> Function() store;
  final Duration interval;
  final Future<void> Function(Duration) _wait;
  final List<Novel> _queue = [];
  final Set<String> _cancelled = {};
  bool _running = false;

  DownloadManager({
    required this.reader,
    required this.store,
    this.interval = const Duration(seconds: 1),
    Future<void> Function(Duration)? wait,
  })  : _wait = wait ?? Future<void>.delayed,
        super(const {});

  DownloadTask? task(String novelId) => state[novelId];

  /// Queues every chapter of [novel] that is not downloaded yet.
  void download(Novel novel) {
    if (state[novel.id]?.isActive ?? false) return;
    _cancelled.remove(novel.id);
    _queue.add(novel);
    _set(DownloadTask(novelId: novel.id, title: novel.title, total: novel.totalChapters));
    unawaited(_drain());
  }

  void cancel(String novelId) {
    final task = state[novelId];
    if (task == null || !task.isActive) return;
    _cancelled.add(novelId);
    _queue.removeWhere((n) => n.id == novelId);
    _set(task.copyWith(status: DownloadStatus.cancelled));
  }

  /// Forgets finished tasks (e.g. after the downloads were deleted).
  void clear(String novelId) {
    if (state[novelId]?.isActive ?? false) return;
    state = Map.of(state)..remove(novelId);
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty && mounted) {
        await _downloadNovel(_queue.removeAt(0));
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _downloadNovel(Novel novel) async {
    final id = novel.id;
    if (_cancelled.contains(id)) return;
    _update(id, (t) => t.copyWith(status: DownloadStatus.running));
    try {
      final s = await store();
      await s.saveNovel(novel);
      final toc = await reader.getToc(id);
      if (toc.fromCache) throw const _DownloadError('需要網路連線才能下載');
      final have = await s.downloadedChapterIds(id);
      final chapters = toc.entries;
      var done = chapters.where((c) => have.contains(c.id)).length;
      _update(id, (t) => t.copyWith(done: done, total: chapters.length));

      for (final entry in chapters.where((c) => !have.contains(c.id))) {
        if (_cancelled.contains(id) || !mounted) return;
        final chapter = await _fetchWithRetry(entry.id);
        if (chapter != null) await s.saveChapter(chapter, downloaded: true);
        done++;
        _update(id, (t) => t.copyWith(done: done));
        if (done < chapters.length) await _wait(interval);
      }
      _update(id, (t) => t.copyWith(status: DownloadStatus.completed));
    } catch (e) {
      final message = e is _DownloadError ? e.message : describeError(e);
      _update(id, (t) => t.copyWith(status: DownloadStatus.failed, error: message));
    }
  }

  /// Fetches a chapter; null when it no longer exists.
  Future<Chapter?> _fetchWithRetry(String chapterId) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await reader.fetchChapter(chapterId, countView: false);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404) return null;
        if (status == 429 && attempt < maxRateLimitRetries) {
          final retryAfter = int.tryParse(e.response?.headers.value('retry-after') ?? '') ?? 30;
          await _wait(Duration(seconds: retryAfter.clamp(1, 120)));
          continue;
        }
        rethrow;
      }
    }
  }

  void _set(DownloadTask task) {
    if (mounted) state = {...state, task.novelId: task};
  }

  void _update(String novelId, DownloadTask Function(DownloadTask) change) {
    final task = state[novelId];
    if (task == null || !mounted) return;
    // A cancelled task keeps its status while the current chapter finishes.
    if (task.status == DownloadStatus.cancelled) return;
    _set(change(task));
  }
}

class _DownloadError implements Exception {
  final String message;

  const _DownloadError(this.message);
}
