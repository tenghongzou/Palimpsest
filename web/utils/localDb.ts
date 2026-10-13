// Offline storage on top of sql.js. These functions take the database as an
// argument so they can be unit tested in Node with a real in-memory SQLite.
import { SQLITE_MIGRATIONS, type SqliteMigration } from '~/utils/sqliteMigrations'

export type SqlValue = string | number | null | Uint8Array

export interface SqlStatement {
  bind(params?: SqlValue[]): boolean
  step(): boolean
  getAsObject(): Record<string, SqlValue>
  free(): boolean
}

/** The subset of the sql.js Database API used here. */
export interface SqlDatabase {
  /** Runs one or more statements; use query() to read rows. */
  exec(sql: string): unknown
  prepare(sql: string): SqlStatement
  export(): Uint8Array
  close(): void
}

export interface CachedChapter {
  id: string
  novel_id: string
  title: string
  content: string
  chapter_number: number
  word_count: number
}

export interface LocalProgress {
  novel_id: string
  chapter_id: string
  paragraph_index: number
  scroll_offset: number
  /** ISO 8601 UTC timestamp */
  read_at: string
  is_synced: number
}

export interface SyncQueueItem {
  id: number
  action: string
  entity_type: string
  entity_id: string
  payload: string | null
  retry_count: number
}

export interface LocalNovel {
  id: string
  title: string
  author_name: string
  cover_url?: string
  description?: string
  status?: string
  language?: string
  total_words?: number
  total_chapters?: number
  avg_rating?: number
  latest_chapter_title?: string
  latest_chapter_at?: string
}

export interface LocalBookshelfItem {
  novel_id: string
  group_name: string
  added_at: string
  novel: LocalNovel
}

const DEFAULT_MAX_CACHE_BYTES = 500 * 1024 * 1024

// Reads and parameterised writes use the Statement API: the minified sql.js
// browser build mangles exec() results (`columns` becomes `lc`) and does not
// bind run()'s parameters correctly. Node's build has neither problem, so
// these bugs only show up in the browser.
export function execute(db: SqlDatabase, sql: string, params: SqlValue[] = []) {
  const stmt = db.prepare(sql)
  try {
    stmt.bind(params)
    stmt.step()
  }
  finally {
    stmt.free()
  }
}

export function query<T>(db: SqlDatabase, sql: string, params: SqlValue[] = []): T[] {
  const stmt = db.prepare(sql)
  try {
    stmt.bind(params)
    const rows: T[] = []
    while (stmt.step()) rows.push(stmt.getAsObject() as T)
    return rows
  }
  finally {
    stmt.free()
  }
}

/** Normalises any date string to ISO 8601 UTC so stored timestamps sort correctly. */
export function toIso(value: string | Date | undefined | null): string {
  const date = value ? new Date(value) : new Date()
  return Number.isNaN(date.getTime()) ? new Date().toISOString() : date.toISOString()
}

// ------------------------------------------------------------------ schema

export function schemaVersion(db: SqlDatabase): number {
  return Number(query<{ user_version: number }>(db, 'PRAGMA user_version')[0]?.user_version ?? 0)
}

/** Applies migrations newer than the database's user_version, each in a transaction. */
export function migrate(db: SqlDatabase, migrations: SqliteMigration[] = SQLITE_MIGRATIONS): number {
  let version = schemaVersion(db)
  for (const m of [...migrations].sort((a, b) => a.version - b.version)) {
    if (m.version <= version) continue
    db.exec('BEGIN')
    try {
      db.exec(m.sql)
      db.exec(`PRAGMA user_version = ${Math.trunc(m.version)}`)
      db.exec('COMMIT')
    }
    catch (error) {
      db.exec('ROLLBACK')
      throw error
    }
    version = m.version
  }
  return version
}

// -------------------------------------------------------------------- meta

export function getMeta(db: SqlDatabase, key: string): string | null {
  return query<{ value: string | null }>(db, 'SELECT value FROM local_meta WHERE key = ?', [key])[0]?.value ?? null
}

export function setMeta(db: SqlDatabase, key: string, value: string | null) {
  execute(
    db,
    `INSERT INTO local_meta (key, value, updated_at) VALUES (?, ?, datetime('now'))
     ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`,
    [key, value],
  )
}

// ------------------------------------------------------------------ novels

export function saveNovel(db: SqlDatabase, novel: LocalNovel) {
  execute(
    db,
    `INSERT INTO local_novels (id, title, author_name, cover_url, description, status, language,
       total_words, total_chapters, avg_rating, latest_chapter_title, latest_chapter_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
     ON CONFLICT(id) DO UPDATE SET
       title = excluded.title, author_name = excluded.author_name, cover_url = excluded.cover_url,
       description = excluded.description, status = excluded.status, language = excluded.language,
       total_words = excluded.total_words, total_chapters = excluded.total_chapters,
       avg_rating = excluded.avg_rating, latest_chapter_title = excluded.latest_chapter_title,
       latest_chapter_at = excluded.latest_chapter_at, updated_at = excluded.updated_at`,
    [
      novel.id, novel.title, novel.author_name, novel.cover_url ?? null, novel.description ?? null,
      novel.status ?? 'ongoing', novel.language ?? 'zh-TW', novel.total_words ?? 0,
      novel.total_chapters ?? 0, novel.avg_rating ?? 0, novel.latest_chapter_title ?? null,
      novel.latest_chapter_at ?? null,
    ],
  )
}

// ---------------------------------------------------------------- chapters

export function saveChapter(db: SqlDatabase, chapter: CachedChapter) {
  execute(
    db,
    `INSERT OR REPLACE INTO local_chapters (id, novel_id, title, content, chapter_number, word_count, is_downloaded, cached_at)
     VALUES (?, ?, ?, ?, ?, ?, 1, datetime('now'))`,
    [chapter.id, chapter.novel_id, chapter.title, chapter.content, chapter.chapter_number, chapter.word_count ?? 0],
  )
}

export function getChapter(db: SqlDatabase, id: string): CachedChapter | null {
  return query<CachedChapter>(
    db,
    'SELECT id, novel_id, title, content, chapter_number, word_count FROM local_chapters WHERE id = ?',
    [id],
  )[0] ?? null
}

/** Table of contents built from the chapters cached for a novel (no content). */
export function cachedChapterList(db: SqlDatabase, novelId: string): Omit<CachedChapter, 'content'>[] {
  return query<Omit<CachedChapter, 'content'>>(
    db,
    `SELECT id, novel_id, title, chapter_number, word_count FROM local_chapters
     WHERE novel_id = ? ORDER BY chapter_number ASC`,
    [novelId],
  )
}

/** Size of cached chapter text in UTF-8 bytes. */
export function cacheSizeBytes(db: SqlDatabase): number {
  return Number(query<{ size: number }>(
    db,
    'SELECT COALESCE(SUM(length(CAST(content AS BLOB))), 0) AS size FROM local_chapters',
  )[0]?.size ?? 0)
}

/** Evicts the least recently cached chapters until the cache fits its limit. */
export function enforceCacheLimit(db: SqlDatabase): number {
  const max = Number(getMeta(db, 'max_cache_size_bytes')) || DEFAULT_MAX_CACHE_BYTES
  let evicted = 0
  let size = cacheSizeBytes(db)
  while (size > max) {
    const oldest = query<{ id: string, bytes: number }>(
      db,
      'SELECT id, length(CAST(content AS BLOB)) AS bytes FROM local_chapters ORDER BY cached_at ASC, rowid ASC LIMIT 1',
    )[0]
    if (!oldest) break
    execute(db, 'DELETE FROM local_chapters WHERE id = ?', [oldest.id])
    size -= Number(oldest.bytes)
    evicted++
  }
  setMeta(db, 'cache_size_bytes', String(size))
  return evicted
}

export function clearChapterCache(db: SqlDatabase) {
  execute(db, 'DELETE FROM local_chapters')
  setMeta(db, 'cache_size_bytes', '0')
}

// ---------------------------------------------------------------- progress

/**
 * Stores progress unless the stored row was read more recently (last read
 * wins, matching the server).
 */
export function saveProgress(db: SqlDatabase, p: Omit<LocalProgress, 'is_synced'>, synced: boolean) {
  execute(
    db,
    `INSERT INTO local_reading_progress (id, novel_id, chapter_id, paragraph_index, scroll_offset, read_at, is_synced)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       chapter_id = excluded.chapter_id, paragraph_index = excluded.paragraph_index,
       scroll_offset = excluded.scroll_offset, read_at = excluded.read_at, is_synced = excluded.is_synced
     WHERE excluded.read_at >= local_reading_progress.read_at`,
    [p.novel_id, p.novel_id, p.chapter_id, p.paragraph_index, p.scroll_offset, toIso(p.read_at), synced ? 1 : 0],
  )
}

export function getProgress(db: SqlDatabase, novelId: string): LocalProgress | null {
  return query<LocalProgress>(
    db,
    `SELECT novel_id, chapter_id, paragraph_index, scroll_offset, read_at, is_synced
     FROM local_reading_progress WHERE novel_id = ?`,
    [novelId],
  )[0] ?? null
}

export function markProgressSynced(db: SqlDatabase, novelId: string, readAt: string) {
  execute(db, 'UPDATE local_reading_progress SET is_synced = 1 WHERE novel_id = ? AND read_at = ?', [novelId, toIso(readAt)])
}

// --------------------------------------------------------------- bookshelf

/** Replaces the local bookshelf mirror with the server's copy. */
export function replaceBookshelf(db: SqlDatabase, items: LocalBookshelfItem[]) {
  db.exec('BEGIN')
  try {
    execute(db, 'DELETE FROM local_bookshelf')
    for (const item of items) {
      saveNovel(db, item.novel)
      execute(
        db,
        `INSERT INTO local_bookshelf (id, novel_id, group_name, added_at, is_synced) VALUES (?, ?, ?, ?, 1)`,
        [item.novel_id, item.novel_id, item.group_name || 'default', toIso(item.added_at)],
      )
    }
    db.exec('COMMIT')
  }
  catch (error) {
    db.exec('ROLLBACK')
    throw error
  }
}

export function listBookshelf(db: SqlDatabase): LocalBookshelfItem[] {
  const rows = query<Record<string, SqlValue>>(
    db,
    `SELECT b.novel_id, b.group_name, b.added_at, n.title, n.author_name, n.cover_url, n.description,
            n.status, n.language, n.total_words, n.total_chapters, n.avg_rating,
            n.latest_chapter_title, n.latest_chapter_at
     FROM local_bookshelf b JOIN local_novels n ON n.id = b.novel_id
     WHERE b.is_deleted = 0
     ORDER BY b.added_at DESC`,
  )
  return rows.map(r => ({
    novel_id: r.novel_id as string,
    group_name: r.group_name as string,
    added_at: r.added_at as string,
    novel: {
      id: r.novel_id as string,
      title: r.title as string,
      author_name: r.author_name as string,
      cover_url: (r.cover_url as string) ?? undefined,
      description: (r.description as string) ?? undefined,
      status: r.status as string,
      language: r.language as string,
      total_words: Number(r.total_words),
      total_chapters: Number(r.total_chapters),
      avg_rating: Number(r.avg_rating),
      latest_chapter_title: (r.latest_chapter_title as string) ?? undefined,
      latest_chapter_at: (r.latest_chapter_at as string) ?? undefined,
    },
  }))
}

// -------------------------------------------------------------- sync queue

/**
 * Queues a change for upload. Only the latest change per entity and action
 * matters, so earlier queued entries for the same entity are replaced.
 */
export function enqueue(db: SqlDatabase, action: string, entityType: string, entityId: string, payload: unknown) {
  execute(db, 'DELETE FROM local_sync_queue WHERE action = ? AND entity_type = ? AND entity_id = ?', [action, entityType, entityId])
  execute(
    db,
    'INSERT INTO local_sync_queue (action, entity_type, entity_id, payload) VALUES (?, ?, ?, ?)',
    [action, entityType, entityId, payload === undefined ? null : JSON.stringify(payload)],
  )
}

export function pendingQueue(db: SqlDatabase, limit = 100): SyncQueueItem[] {
  return query<SyncQueueItem>(
    db,
    'SELECT id, action, entity_type, entity_id, payload, retry_count FROM local_sync_queue ORDER BY id ASC LIMIT ?',
    [limit],
  )
}

export function removeQueued(db: SqlDatabase, id: number) {
  execute(db, 'DELETE FROM local_sync_queue WHERE id = ?', [id])
}

export function markRetry(db: SqlDatabase, id: number) {
  execute(db, 'UPDATE local_sync_queue SET retry_count = retry_count + 1 WHERE id = ?', [id])
}
