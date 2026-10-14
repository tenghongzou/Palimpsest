import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/offline_store.dart';
import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/utils/uuid.dart';
import '../domain/entities/bookmark.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return BookmarkRepository(
    store: ref.read(offlineStoreProvider),
    sync: ref.read(syncServiceProvider),
    isSignedIn: () => api.hasAccessToken,
  );
});

/// Bookmarks live in local SQLite first (local_bookmarks, client-generated
/// ids) so they work offline; changes are synced via POST /bookmarks/sync.
class BookmarkRepository {
  final Future<OfflineStore> Function() store;
  final SyncService sync;
  final bool Function() isSignedIn;

  BookmarkRepository({required this.store, required this.sync, required this.isSignedIn});

  Future<List<Bookmark>> list({String? novelId}) async => (await store()).bookmarks(novelId: novelId);

  Future<Bookmark> add({
    required String novelId,
    required String chapterId,
    String? chapterTitle,
    int paragraphIndex = 0,
    String? note,
  }) async {
    final bookmark = Bookmark(
      id: generateUuidV4(),
      novelId: novelId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      paragraphIndex: paragraphIndex,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    await (await store()).insertBookmark(bookmark);
    await _queueSync();
    return bookmark;
  }

  Future<void> updateNote(String id, String? note) async {
    await (await store()).updateBookmarkNote(id, note == null || note.trim().isEmpty ? null : note.trim());
    await _queueSync();
  }

  Future<void> delete(String id) async {
    await (await store()).markBookmarkDeleted(id);
    await _queueSync();
  }

  /// Uploads local changes and pulls bookmarks made on other devices.
  Future<void> syncNow() async {
    if (!isSignedIn()) return;
    await sync.requestBookmarkSync();
    // A push already in flight may have started before the request was queued.
    for (var i = 0; i < 2; i++) {
      await sync.pushPending();
      if (await (await store()).queued('sync', bookmarkSyncEntity, 'all') == null) break;
    }
  }

  Future<void> _queueSync() async {
    if (isSignedIn()) await sync.requestBookmarkSync();
  }
}
