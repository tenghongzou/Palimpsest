import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/reader/domain/entities/bookmark.dart';
import '../database/database_helper.dart';
import '../database/offline_store.dart';
import '../network/api_client.dart';

/// Uploads one queued change; throws on failure.
typedef SendQueued = Future<void> Function(SyncQueueItem item);

final syncServiceProvider = Provider<SyncService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final store = ref.read(offlineStoreProvider);
  final service = SyncService(
    store: store,
    send: (item) async => sendQueuedItem(apiClient.dio, item, store: await store()),
    canPush: () => apiClient.hasAccessToken,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Bookmark changes are synced as a whole through one queue entry.
const bookmarkSyncEntity = 'bookmarks';

Future<void> sendQueuedItem(Dio dio, SyncQueueItem item, {OfflineStore? store}) async {
  if (item.entityType == 'progress' && item.action == 'update') {
    await dio.put('/reading-progress/${item.entityId}', data: item.payload);
    return;
  }
  if (item.entityType == bookmarkSyncEntity && item.action == 'sync' && store != null) {
    await syncBookmarks(dio, store);
    return;
  }
  throw StateError('unknown sync item ${item.entityType}/${item.action}');
}

/// The server accepts at most this many bookmark changes per sync request.
const maxBookmarkChangesPerSync = 500;

/// Uploads bookmarks changed offline through POST /bookmarks/sync and
/// replaces the local list with the server's full list.
Future<void> syncBookmarks(Dio dio, OfflineStore store) async {
  final pending = await store.pendingBookmarkChanges();
  var upserts = pending.upserts;
  var deletes = pending.deletes;
  do {
    final sendUpserts = upserts.take(maxBookmarkChangesPerSync).toList();
    final sendDeletes = deletes.take(maxBookmarkChangesPerSync - sendUpserts.length).toList();
    upserts = upserts.skip(sendUpserts.length).toList();
    deletes = deletes.skip(sendDeletes.length).toList();

    final response = await dio.post('/bookmarks/sync', data: {
      'upserts': sendUpserts.map((b) => b.toSyncJson()).toList(),
      'deletes': sendDeletes,
    });
    final server = (response.data['data'] as List? ?? const [])
        .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
        .toList();
    await store.applyBookmarkSync(sentUpserts: sendUpserts, sentDeletes: sendDeletes, server: server);
  } while (upserts.isNotEmpty || deletes.isNotEmpty);
  await store.setMeta('last_sync_at', DateTime.now().toUtc().toIso8601String());
}

/// Records reading progress and bookmark changes locally and uploads queued
/// changes, so what is done offline reaches the server once back online.
class SyncService {
  static const maxRetries = 5;

  final Future<OfflineStore> Function() store;
  final SendQueued send;

  /// Whether uploads can be attempted (e.g. a user is signed in). Queued
  /// changes wait while this is false.
  final bool Function() canPush;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Future<int>? _pushing;

  SyncService({required this.store, required this.send, bool Function()? canPush})
      : canPush = canPush ?? _always;

  static bool _always() => true;

  /// Starts uploading whenever connectivity comes back.
  void listenForConnectivity() {
    _connectivity ??= Connectivity().onConnectivityChanged.listen(
      (results) {
        if (results.any((r) => r != ConnectivityResult.none)) unawaited(pushPending());
      },
      // No connectivity service (e.g. Linux without NetworkManager): offline
      // changes then go up with the next progress report or sign-in.
      onError: (Object _) {},
    );
  }

  void dispose() => _connectivity?.cancel();

  /// Saves the reading position locally and, when [upload] is set, queues it
  /// for the server. [duration] is the number of seconds read since the last
  /// report; durations of reports not uploaded yet are added together.
  Future<void> recordProgress({
    required String novelId,
    required String chapterId,
    double scrollOffset = 1,
    int paragraphIndex = 0,
    int duration = 0,
    bool upload = true,
  }) async {
    final s = await store();
    final readAt = DateTime.now().toUtc();
    final offset = scrollOffset.clamp(0.0, 1.0).toDouble();
    await s.saveProgress(
      novelId: novelId,
      chapterId: chapterId,
      scrollOffset: offset,
      paragraphIndex: paragraphIndex,
      readAt: readAt,
    );
    if (!upload) return;

    // Let an upload in flight finish so its duration is not counted twice.
    final inFlight = _pushing;
    if (inFlight != null) await inFlight.catchError((_) => 0);
    final pending = await s.queued('update', 'progress', novelId);
    final pendingDuration = (pending?.payload?['duration'] as num?)?.toInt() ?? 0;
    final total = pendingDuration + (duration < 0 ? 0 : duration);

    await s.enqueue('update', 'progress', novelId, {
      'chapter_id': chapterId,
      'paragraph_index': paragraphIndex < 0 ? 0 : paragraphIndex,
      'scroll_offset': offset,
      'read_at': readAt.toIso8601String(),
      if (total > 0) 'duration': total,
    });
    unawaited(pushPending());
  }

  /// Queues a bookmark sync (local changes up, the server's list down).
  Future<void> requestBookmarkSync() async {
    final s = await store();
    await s.enqueue('sync', bookmarkSyncEntity, 'all', null);
    unawaited(pushPending());
  }

  /// Uploads queued changes in order; concurrent calls share one run.
  Future<int> pushPending() {
    return _pushing ??= _push().whenComplete(() => _pushing = null);
  }

  Future<int> _push() async {
    if (!canPush()) return 0;
    final s = await store();
    var sent = 0;
    for (final item in await s.pendingQueue()) {
      try {
        await send(item);
        await s.removeQueued(item.id);
        final readAt = item.payload?['read_at'] as String?;
        if (item.entityType == 'progress' && readAt != null) {
          await s.markProgressSynced(item.entityId, readAt);
        }
        sent++;
      } catch (e) {
        if (_isPermanentFailure(e) || item.retryCount + 1 >= maxRetries) {
          await s.removeQueued(item.id);
          continue;
        }
        // Stop at the first transient failure so nothing is reordered.
        await s.markRetry(item.id);
        break;
      }
    }
    return sent;
  }

  /// A rejection the server will repeat no matter how often we retry.
  static bool _isPermanentFailure(Object error) {
    if (error is! DioException) return error is StateError;
    final status = error.response?.statusCode;
    return status != null && status >= 400 && status < 500 && ![401, 408, 429].contains(status);
  }
}
