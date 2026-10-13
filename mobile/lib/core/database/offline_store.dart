import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/reader/domain/entities/chapter.dart';

/// A queued change waiting to be uploaded.
class SyncQueueItem {
  final int id;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? payload;
  final int retryCount;

  const SyncQueueItem({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.retryCount,
  });
}

/// Offline chapter cache, reading progress and sync queue on top of the local
/// SQLite database. Mirrors web/utils/localDb.ts so both clients behave alike.
class OfflineStore {
  static const _defaultMaxCacheBytes = 500 * 1024 * 1024;

  final Database db;

  OfflineStore(this.db);

  // ------------------------------------------------------------ chapters

  Future<void> saveChapter(Chapter chapter) async {
    await db.rawInsert('''
      INSERT OR REPLACE INTO local_chapters
        (id, novel_id, title, content, chapter_number, word_count, is_downloaded, cached_at)
      VALUES (?, ?, ?, ?, ?, ?, 1, datetime('now'))
    ''', [
      chapter.id, chapter.novelId, chapter.title, chapter.content,
      chapter.chapterNumber, chapter.wordCount,
    ]);
  }

  Future<Chapter?> getChapter(String id) async {
    final rows = await db.query('local_chapters', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Chapter(
      id: r['id'] as String,
      novelId: r['novel_id'] as String,
      title: r['title'] as String,
      content: r['content'] as String,
      chapterNumber: r['chapter_number'] as int,
      wordCount: r['word_count'] as int? ?? 0,
      fromCache: true,
    );
  }

  /// Size of cached chapter text in UTF-8 bytes.
  Future<int> cacheSizeBytes() async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(LENGTH(CAST(content AS BLOB))), 0) AS size FROM local_chapters',
    );
    return (rows.first['size'] as int?) ?? 0;
  }

  /// Evicts the least recently cached chapters until the cache fits its limit.
  Future<int> enforceCacheLimit() async {
    final meta = await db.query('local_meta', where: 'key = ?', whereArgs: ['max_cache_size_bytes']);
    final max = int.tryParse(meta.isEmpty ? '' : meta.first['value'] as String? ?? '') ?? _defaultMaxCacheBytes;
    var size = await cacheSizeBytes();
    var evicted = 0;
    while (size > max) {
      final oldest = await db.rawQuery(
        'SELECT id, LENGTH(CAST(content AS BLOB)) AS bytes FROM local_chapters ORDER BY cached_at ASC, rowid ASC LIMIT 1',
      );
      if (oldest.isEmpty) break;
      await db.delete('local_chapters', where: 'id = ?', whereArgs: [oldest.first['id']]);
      size -= oldest.first['bytes'] as int;
      evicted++;
    }
    return evicted;
  }

  // ------------------------------------------------------------ progress

  /// Stores progress unless the stored row was read more recently
  /// (last read wins, matching the server).
  Future<void> saveProgress({
    required String novelId,
    required String chapterId,
    required double scrollOffset,
    required DateTime readAt,
    int paragraphIndex = 0,
    bool synced = false,
  }) async {
    await db.rawInsert('''
      INSERT INTO local_reading_progress
        (id, novel_id, chapter_id, paragraph_index, scroll_offset, read_at, is_synced)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        chapter_id = excluded.chapter_id, paragraph_index = excluded.paragraph_index,
        scroll_offset = excluded.scroll_offset, read_at = excluded.read_at, is_synced = excluded.is_synced
      WHERE excluded.read_at >= local_reading_progress.read_at
    ''', [
      novelId, novelId, chapterId, paragraphIndex, scrollOffset,
      readAt.toUtc().toIso8601String(), synced ? 1 : 0,
    ]);
  }

  Future<Map<String, Object?>?> getProgress(String novelId) async {
    final rows = await db.query('local_reading_progress', where: 'novel_id = ?', whereArgs: [novelId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markProgressSynced(String novelId, String readAt) async {
    await db.update(
      'local_reading_progress',
      {'is_synced': 1},
      where: 'novel_id = ? AND read_at = ?',
      whereArgs: [novelId, readAt],
    );
  }

  // ---------------------------------------------------------- sync queue

  /// Queues a change for upload, replacing earlier queued changes to the
  /// same entity since only the latest one matters.
  Future<void> enqueue(String action, String entityType, String entityId, Map<String, dynamic>? payload) async {
    await db.transaction((txn) async {
      await txn.delete(
        'local_sync_queue',
        where: 'action = ? AND entity_type = ? AND entity_id = ?',
        whereArgs: [action, entityType, entityId],
      );
      await txn.insert('local_sync_queue', {
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'payload': payload == null ? null : jsonEncode(payload),
      });
    });
  }

  Future<List<SyncQueueItem>> pendingQueue({int limit = 100}) async {
    final rows = await db.query('local_sync_queue', orderBy: 'id ASC', limit: limit);
    return rows.map((r) {
      final payload = r['payload'] as String?;
      return SyncQueueItem(
        id: r['id'] as int,
        action: r['action'] as String,
        entityType: r['entity_type'] as String,
        entityId: r['entity_id'] as String,
        payload: payload == null ? null : jsonDecode(payload) as Map<String, dynamic>,
        retryCount: r['retry_count'] as int? ?? 0,
      );
    }).toList();
  }

  Future<void> removeQueued(int id) async {
    await db.delete('local_sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markRetry(int id) async {
    await db.rawUpdate('UPDATE local_sync_queue SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }
}
