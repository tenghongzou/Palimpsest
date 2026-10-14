import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/bookstore/domain/entities/novel.dart';
import '../../features/reader/domain/entities/bookmark.dart';
import '../../features/reader/domain/entities/chapter.dart';
import '../../features/reader/domain/entities/reading_settings.dart';

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

/// A chapter stored on the device (content omitted).
class LocalChapterInfo {
  final String id;
  final String title;
  final int chapterNumber;
  final int wordCount;
  final bool isDownloaded;

  const LocalChapterInfo({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.wordCount,
    required this.isDownloaded,
  });
}

/// A novel with chapters downloaded for offline reading.
class DownloadedNovel {
  final String novelId;
  final String title;
  final String? authorName;
  final String? coverUrl;
  final int downloadedChapters;
  final int totalChapters;
  final int sizeBytes;

  const DownloadedNovel({
    required this.novelId,
    required this.title,
    this.authorName,
    this.coverUrl,
    required this.downloadedChapters,
    required this.totalChapters,
    required this.sizeBytes,
  });

  bool get isComplete => totalChapters > 0 && downloadedChapters >= totalChapters;
}

/// A cached chapter translation.
class CachedTranslation {
  final String title;
  final String content;
  final String sourceLang;

  const CachedTranslation({required this.title, required this.content, required this.sourceLang});
}

/// Offline chapter cache, downloads, reading progress, bookmarks and the sync
/// queue on top of the local SQLite database (schema from
/// shared/sqlite-schema). Mirrors web/utils/localDb.ts so both clients behave
/// alike.
class OfflineStore {
  static const _defaultMaxCacheBytes = 500 * 1024 * 1024;
  static const _searchHistoryLimit = 20;

  final Database db;

  OfflineStore(this.db);

  // ------------------------------------------------------------ chapters

  /// Caches [chapter]. Chapters fetched while reading are evictable cache;
  /// [downloaded] marks chapters the user downloaded explicitly. A chapter
  /// once downloaded stays downloaded when it is re-cached by reading.
  Future<void> saveChapter(Chapter chapter, {bool downloaded = false}) async {
    await db.transaction((txn) async {
      final existing = await txn.query(
        'local_chapters',
        columns: ['is_downloaded'],
        where: 'id = ?',
        whereArgs: [chapter.id],
      );
      final wasDownloaded = existing.isNotEmpty && existing.first['is_downloaded'] == 1;
      await txn.rawInsert('''
        INSERT OR REPLACE INTO local_chapters
          (id, novel_id, title, content, chapter_number, word_count, is_downloaded, cached_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        chapter.id, chapter.novelId, chapter.title, chapter.content,
        chapter.chapterNumber, chapter.wordCount, (downloaded || wasDownloaded) ? 1 : 0,
        _now(),
      ]);
    });
  }

  Future<Chapter?> getChapter(String id) async {
    final rows = await db.query('local_chapters', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final chapter = Chapter(
      id: r['id'] as String,
      novelId: r['novel_id'] as String,
      title: r['title'] as String,
      content: r['content'] as String,
      chapterNumber: r['chapter_number'] as int,
      wordCount: r['word_count'] as int? ?? 0,
      fromCache: true,
    );
    final (prev, next) = await neighbours(chapter.novelId, chapter.chapterNumber);
    return chapter.copyWith(prevChapter: prev, nextChapter: next);
  }

  /// The closest stored chapters before and after [chapterNumber], used to
  /// navigate offline when the server's prev/next links are unavailable.
  Future<(ChapterRef?, ChapterRef?)> neighbours(String novelId, int chapterNumber) async {
    Future<ChapterRef?> pick(String where, String order) async {
      final rows = await db.query(
        'local_chapters',
        columns: ['id', 'title', 'chapter_number'],
        where: 'novel_id = ? AND $where',
        whereArgs: [novelId, chapterNumber],
        orderBy: 'chapter_number $order',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ChapterRef(
        id: rows.first['id'] as String,
        title: rows.first['title'] as String,
        chapterNumber: rows.first['chapter_number'] as int,
      );
    }

    return (await pick('chapter_number < ?', 'DESC'), await pick('chapter_number > ?', 'ASC'));
  }

  /// Chapters of [novelId] stored on the device, in reading order.
  Future<List<LocalChapterInfo>> listChapters(String novelId) async {
    final rows = await db.query(
      'local_chapters',
      columns: ['id', 'title', 'chapter_number', 'word_count', 'is_downloaded'],
      where: 'novel_id = ?',
      whereArgs: [novelId],
      orderBy: 'chapter_number ASC',
    );
    return rows
        .map((r) => LocalChapterInfo(
              id: r['id'] as String,
              title: r['title'] as String,
              chapterNumber: r['chapter_number'] as int,
              wordCount: r['word_count'] as int? ?? 0,
              isDownloaded: r['is_downloaded'] == 1,
            ))
        .toList();
  }

  Future<Set<String>> downloadedChapterIds(String novelId) async {
    final rows = await db.query(
      'local_chapters',
      columns: ['id'],
      where: 'novel_id = ? AND is_downloaded = 1',
      whereArgs: [novelId],
    );
    return rows.map((r) => r['id'] as String).toSet();
  }

  /// Size of stored chapter text in UTF-8 bytes; [downloaded] restricts it to
  /// downloaded (true) or merely cached (false) chapters.
  Future<int> cacheSizeBytes({bool? downloaded}) async {
    final where = downloaded == null ? '' : ' WHERE is_downloaded = ${downloaded ? 1 : 0}';
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(LENGTH(CAST(content AS BLOB))), 0) AS size FROM local_chapters$where',
    );
    return (rows.first['size'] as int?) ?? 0;
  }

  /// Evicts the least recently cached chapters until the cache fits its
  /// limit. Downloaded chapters are only removed by the user.
  Future<int> enforceCacheLimit() async {
    final max = int.tryParse(await getMeta('max_cache_size_bytes') ?? '') ?? _defaultMaxCacheBytes;
    var size = await cacheSizeBytes();
    var evicted = 0;
    while (size > max) {
      final oldest = await db.rawQuery(
        'SELECT id, LENGTH(CAST(content AS BLOB)) AS bytes FROM local_chapters '
        'WHERE is_downloaded = 0 ORDER BY cached_at ASC, rowid ASC LIMIT 1',
      );
      if (oldest.isEmpty) break;
      await db.delete('local_chapters', where: 'id = ?', whereArgs: [oldest.first['id']]);
      size -= oldest.first['bytes'] as int;
      evicted++;
    }
    await _updateCacheSizeMeta();
    return evicted;
  }

  /// Removes chapters cached while reading, keeping downloads.
  Future<void> clearCachedChapters() async {
    await db.delete('local_chapters', where: 'is_downloaded = 0');
    await _updateCacheSizeMeta();
  }

  Future<void> _updateCacheSizeMeta() async {
    await setMeta('cache_size_bytes', '${await cacheSizeBytes()}');
  }

  // -------------------------------------------------------------- novels

  Future<void> saveNovel(Novel novel) async {
    await db.rawInsert('''
      INSERT OR REPLACE INTO local_novels
        (id, title, author_name, cover_url, description, status, language,
         total_words, total_chapters, avg_rating, latest_chapter_title, latest_chapter_at,
         cached_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      novel.id, novel.title, novel.authorName, novel.coverUrl, novel.description,
      novel.status, novel.language, novel.totalWords, novel.totalChapters, novel.avgRating,
      novel.latestChapterTitle, novel.latestChapterAt?.toUtc().toIso8601String(),
      _now(), _now(),
    ]);
  }

  Future<List<DownloadedNovel>> downloadedNovels() async {
    final rows = await db.rawQuery('''
      SELECT c.novel_id AS novel_id,
             COUNT(*) AS chapters,
             COALESCE(SUM(LENGTH(CAST(c.content AS BLOB))), 0) AS bytes,
             n.title AS title, n.author_name AS author_name, n.cover_url AS cover_url,
             n.total_chapters AS total_chapters
      FROM local_chapters c
      LEFT JOIN local_novels n ON n.id = c.novel_id
      WHERE c.is_downloaded = 1
      GROUP BY c.novel_id
      ORDER BY MAX(c.cached_at) DESC
    ''');
    return rows
        .map((r) => DownloadedNovel(
              novelId: r['novel_id'] as String,
              title: r['title'] as String? ?? '未知作品',
              authorName: r['author_name'] as String?,
              coverUrl: r['cover_url'] as String?,
              downloadedChapters: r['chapters'] as int,
              totalChapters: r['total_chapters'] as int? ?? 0,
              sizeBytes: r['bytes'] as int,
            ))
        .toList();
  }

  /// Deletes every stored chapter of [novelId] and its novel record.
  Future<void> deleteDownloadedNovel(String novelId) async {
    await db.transaction((txn) async {
      await txn.delete('local_chapters', where: 'novel_id = ?', whereArgs: [novelId]);
      await txn.delete('local_novels', where: 'id = ?', whereArgs: [novelId]);
    });
    await _updateCacheSizeMeta();
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
    final readAtIso = readAt.toUtc().toIso8601String();
    await db.transaction((txn) async {
      final existing = await txn.query(
        'local_reading_progress',
        columns: ['read_at'],
        where: 'novel_id = ?',
        whereArgs: [novelId],
      );
      if (existing.isNotEmpty && (existing.first['read_at'] as String? ?? '').compareTo(readAtIso) > 0) {
        return;
      }
      await txn.rawInsert('''
        INSERT OR REPLACE INTO local_reading_progress
          (id, novel_id, chapter_id, paragraph_index, scroll_offset, read_at, is_synced)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [novelId, novelId, chapterId, paragraphIndex, scrollOffset, readAtIso, synced ? 1 : 0]);
    });
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

  // ----------------------------------------------------------- bookmarks

  Future<void> insertBookmark(Bookmark bookmark) async {
    await db.insert('local_bookmarks', {
      'id': bookmark.id,
      'novel_id': bookmark.novelId,
      'chapter_id': bookmark.chapterId,
      'chapter_title': bookmark.chapterTitle,
      'paragraph_index': bookmark.paragraphIndex,
      'note': bookmark.note,
      'created_at': bookmark.createdAt.toUtc().toIso8601String(),
      'is_synced': bookmark.isSynced ? 1 : 0,
      'is_deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBookmarkNote(String id, String? note) async {
    await db.update('local_bookmarks', {'note': note, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
  }

  /// Marks a bookmark deleted; the row stays until the deletion is synced.
  Future<void> markBookmarkDeleted(String id) async {
    await db.update('local_bookmarks', {'is_deleted': 1, 'is_synced': 0}, where: 'id = ?', whereArgs: [id]);
  }

  /// Active bookmarks, newest first.
  Future<List<Bookmark>> bookmarks({String? novelId}) async {
    final rows = await db.query(
      'local_bookmarks',
      where: novelId == null ? 'is_deleted = 0' : 'is_deleted = 0 AND novel_id = ?',
      whereArgs: novelId == null ? null : [novelId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_bookmarkFromRow).toList();
  }

  /// Bookmarks changed locally and not yet synced, including deletions.
  Future<({List<Bookmark> upserts, List<String> deletes})> pendingBookmarkChanges() async {
    final rows = await db.query('local_bookmarks', where: 'is_synced = 0', orderBy: 'created_at ASC');
    return (
      upserts: rows.where((r) => r['is_deleted'] == 0).map(_bookmarkFromRow).toList(),
      deletes: rows.where((r) => r['is_deleted'] == 1).map((r) => r['id'] as String).toList(),
    );
  }

  /// Reconciles local bookmarks with the server's full list after
  /// POST /bookmarks/sync. Local changes made while the request was in
  /// flight are kept for the next sync.
  Future<void> applyBookmarkSync({
    required List<Bookmark> sentUpserts,
    required List<String> sentDeletes,
    required List<Bookmark> server,
  }) async {
    await db.transaction((txn) async {
      for (final id in sentDeletes) {
        await txn.delete('local_bookmarks', where: 'id = ? AND is_deleted = 1', whereArgs: [id]);
      }
      final sent = {for (final b in sentUpserts) b.id: b};
      final rows = await txn.query('local_bookmarks');
      final local = {for (final r in rows) r['id'] as String: r};
      final serverIds = server.map((b) => b.id).toSet();

      bool unchangedSinceSent(Map<String, Object?> row) {
        final snapshot = sent[row['id']];
        return snapshot != null &&
            row['is_deleted'] == 0 &&
            row['note'] == snapshot.note &&
            row['paragraph_index'] == snapshot.paragraphIndex;
      }

      for (final b in server) {
        final row = local[b.id];
        if (row != null && row['is_synced'] == 0 && !unchangedSinceSent(row)) continue;
        await txn.insert('local_bookmarks', {
          'id': b.id,
          'novel_id': b.novelId,
          'chapter_id': b.chapterId,
          'chapter_title': b.chapterTitle ?? row?['chapter_title'],
          'paragraph_index': b.paragraphIndex,
          'note': b.note,
          'created_at': b.createdAt.toUtc().toIso8601String(),
          'is_synced': 1,
          'is_deleted': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final row in rows) {
        final id = row['id'] as String;
        if (serverIds.contains(id)) continue;
        // Synced bookmarks missing on the server were deleted on another
        // device; sent ones the server skipped (e.g. deleted chapters) are gone too.
        if (row['is_synced'] == 1 || unchangedSinceSent(row)) {
          await txn.delete('local_bookmarks', where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }

  Bookmark _bookmarkFromRow(Map<String, Object?> r) => Bookmark(
        id: r['id'] as String,
        novelId: r['novel_id'] as String,
        chapterId: r['chapter_id'] as String,
        chapterTitle: r['chapter_title'] as String?,
        paragraphIndex: r['paragraph_index'] as int? ?? 0,
        note: r['note'] as String?,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
        isSynced: r['is_synced'] == 1,
      );

  // --------------------------------------------------------- translation

  Future<CachedTranslation?> getTranslation(String chapterId, String targetLang) async {
    final rows = await db.query(
      'local_translation_cache',
      where: 'chapter_id = ? AND target_lang = ?',
      whereArgs: [chapterId, targetLang],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    // translated_text holds the title on its first line, then the content.
    final text = rows.first['translated_text'] as String;
    final split = text.indexOf('\n');
    return CachedTranslation(
      title: split == -1 ? text : text.substring(0, split),
      content: split == -1 ? '' : text.substring(split + 1),
      sourceLang: rows.first['source_lang'] as String,
    );
  }

  Future<void> saveTranslation({
    required String chapterId,
    required String sourceLang,
    required String targetLang,
    required String title,
    required String content,
  }) async {
    await db.insert('local_translation_cache', {
      'id': '$chapterId:$sourceLang:$targetLang',
      'chapter_id': chapterId,
      'source_lang': sourceLang,
      'target_lang': targetLang,
      'translated_text': '${title.replaceAll('\n', ' ')}\n$content',
      'cached_at': _now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------ search history

  Future<void> addSearchKeyword(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return;
    await db.transaction((txn) async {
      await txn.delete('local_search_history', where: 'keyword = ?', whereArgs: [k]);
      await txn.insert('local_search_history', {'keyword': k, 'searched_at': _now()});
      await txn.rawDelete(
        'DELETE FROM local_search_history WHERE id NOT IN '
        '(SELECT id FROM local_search_history ORDER BY id DESC LIMIT $_searchHistoryLimit)',
      );
    });
  }

  Future<List<String>> recentSearches({int limit = 10}) async {
    final rows = await db.query('local_search_history', orderBy: 'id DESC', limit: limit);
    return rows.map((r) => r['keyword'] as String).toList();
  }

  Future<void> clearSearchHistory() => db.delete('local_search_history');

  // ---------------------------------------------------- reading settings

  Future<void> saveReadingSettings(ReadingSettings s, {DateTime? updatedAt}) async {
    await db.insert('local_reading_settings', {
      'id': 1,
      'font_size': s.fontSize,
      'line_height': s.lineHeight,
      'letter_spacing': s.letterSpacing,
      'margin': s.margin,
      'font_family': s.fontFamily,
      'theme': s.theme,
      'reading_mode': s.readingMode,
      'brightness': s.brightness,
      'keep_screen_on': s.keepScreenOn ? 1 : 0,
      'auto_chapter': s.autoChapter ? 1 : 0,
      'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// The stored settings and when they last changed, or null if never saved.
  Future<(ReadingSettings, DateTime?)?> loadReadingSettings() async {
    final rows = await db.query('local_reading_settings', where: 'id = 1');
    if (rows.isEmpty) return null;
    final d = rows.first;
    final settings = ReadingSettings(
      fontSize: d['font_size'] as int? ?? 18,
      lineHeight: (d['line_height'] as num?)?.toDouble() ?? 1.8,
      letterSpacing: (d['letter_spacing'] as num?)?.toDouble() ?? 0.0,
      margin: d['margin'] as int? ?? 16,
      fontFamily: d['font_family'] as String? ?? 'system',
      theme: ReadingSettings.normalizeTheme(d['theme'] as String?),
      readingMode: d['reading_mode'] as String? ?? 'scroll',
      brightness: d['brightness'] as int? ?? 100,
      keepScreenOn: (d['keep_screen_on'] as int? ?? 1) == 1,
      autoChapter: (d['auto_chapter'] as int? ?? 1) == 1,
    );
    return (settings, _parseStoredTime(d['updated_at'] as String?));
  }

  /// Removes the signed-in user's personal data (progress, bookmarks,
  /// bookshelf and unsent changes) so the next account on this device
  /// neither sees nor uploads it. Downloaded chapters are kept.
  Future<void> clearUserData() async {
    await db.transaction((txn) async {
      for (final table in ['local_bookmarks', 'local_sync_queue', 'local_reading_progress', 'local_bookshelf']) {
        await txn.delete(table);
      }
    });
    await setMeta('last_sync_at', null);
  }

  // ----------------------------------------------------------------- meta

  Future<String?> getMeta(String key) async {
    final rows = await db.query('local_meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) async {
    await db.insert(
      'local_meta',
      {'key': key, 'value': value, 'updated_at': _now()},
      conflictAlgorithm: ConflictAlgorithm.replace,
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

  Future<SyncQueueItem?> queued(String action, String entityType, String entityId) async {
    final rows = await db.query(
      'local_sync_queue',
      where: 'action = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [action, entityType, entityId],
      limit: 1,
    );
    return rows.isEmpty ? null : _queueItem(rows.first);
  }

  Future<List<SyncQueueItem>> pendingQueue({int limit = 100}) async {
    final rows = await db.query('local_sync_queue', orderBy: 'id ASC', limit: limit);
    return rows.map(_queueItem).toList();
  }

  SyncQueueItem _queueItem(Map<String, Object?> r) {
    final payload = r['payload'] as String?;
    return SyncQueueItem(
      id: r['id'] as int,
      action: r['action'] as String,
      entityType: r['entity_type'] as String,
      entityId: r['entity_id'] as String,
      payload: payload == null ? null : jsonDecode(payload) as Map<String, dynamic>,
      retryCount: r['retry_count'] as int? ?? 0,
    );
  }

  Future<void> removeQueued(int id) async {
    await db.delete('local_sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markRetry(int id) async {
    await db.rawUpdate('UPDATE local_sync_queue SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  /// Parses an ISO time, or SQLite's `datetime('now')` format (UTC).
  static DateTime? _parseStoredTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final hasZone = value.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(value);
    return DateTime.tryParse(hasZone ? value : '${value.replaceFirst(' ', 'T')}Z');
  }
}
