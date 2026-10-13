import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../database/offline_store.dart';
import '../network/api_client.dart';

/// Uploads one queued change; throws on failure.
typedef SendQueued = Future<void> Function(SyncQueueItem item);

final syncServiceProvider = Provider<SyncService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final service = SyncService(
    store: () async => OfflineStore(await DatabaseHelper.database),
    send: (item) => sendQueuedItem(apiClient.dio, item),
  );
  ref.onDispose(service.dispose);
  return service;
});

Future<void> sendQueuedItem(Dio dio, SyncQueueItem item) async {
  if (item.entityType == 'progress' && item.action == 'update') {
    await dio.put('/reading-progress/${item.entityId}', data: item.payload);
    return;
  }
  throw StateError('unknown sync item ${item.entityType}/${item.action}');
}

/// Records reading progress locally and uploads queued changes, so progress
/// made offline reaches the server once the device is back online.
class SyncService {
  static const maxRetries = 5;

  final Future<OfflineStore> Function() store;
  final SendQueued send;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Future<int>? _pushing;

  SyncService({required this.store, required this.send});

  /// Starts uploading whenever connectivity comes back.
  void listenForConnectivity() {
    _connectivity ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) unawaited(pushPending());
    });
  }

  void dispose() => _connectivity?.cancel();

  Future<void> recordProgress({
    required String novelId,
    required String chapterId,
    double scrollOffset = 1,
  }) async {
    final s = await store();
    final readAt = DateTime.now().toUtc();
    await s.saveProgress(novelId: novelId, chapterId: chapterId, scrollOffset: scrollOffset, readAt: readAt);
    await s.enqueue('update', 'progress', novelId, {
      'chapter_id': chapterId,
      'paragraph_index': 0,
      'scroll_offset': scrollOffset,
      'read_at': readAt.toIso8601String(),
    });
    unawaited(pushPending());
  }

  /// Uploads queued changes in order; concurrent calls share one run.
  Future<int> pushPending() {
    return _pushing ??= _push().whenComplete(() => _pushing = null);
  }

  Future<int> _push() async {
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
