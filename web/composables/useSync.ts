// Data sync between local SQLite and server
import { apiFetch, statusOf, type ApiResponse } from '~/utils/api'
import {
  getMeta,
  markProgressSynced,
  markRetry,
  pendingQueue,
  query,
  removeQueued,
  replaceBookmarks,
  replaceBookshelf,
  saveProgress,
  setMeta,
  type LocalBookshelfItem,
  type LocalProgress,
  type ServerBookmark,
  type SqlDatabase,
  type SyncQueueItem,
} from '~/utils/localDb'

const MAX_RETRIES = 5

interface ServerProgress {
  novel_id: string
  chapter_id: string
  paragraph_index: number
  scroll_offset: number
  read_at: string
}

/** Uploads one queued change. Throws on failure. */
async function sendQueued(item: SyncQueueItem) {
  const payload = item.payload ? JSON.parse(item.payload) : undefined
  if (item.entity_type === 'progress' && item.action === 'update') {
    await apiFetch(`/reading-progress/${item.entity_id}`, { method: 'PUT', body: payload })
    return
  }
  throw new Error(`unknown sync item ${item.entity_type}/${item.action}`)
}

/** A rejection the server will repeat no matter how often we retry. */
function isPermanentFailure(status: number | undefined) {
  return status !== undefined && status >= 400 && status < 500 && ![401, 408, 429].includes(status)
}

/**
 * Uploads queued changes in order. Stops at the first transient failure so
 * nothing is reordered; permanently rejected items are dropped.
 * Returns the number of items uploaded.
 */
export async function pushQueue(db: SqlDatabase, send = sendQueued): Promise<number> {
  let sent = 0
  // Bookmarks go up in one batch through pushBookmarks.
  for (const item of pendingQueue(db).filter(i => i.entity_type !== 'bookmark')) {
    try {
      await send(item)
      removeQueued(db, item.id)
      if (item.entity_type === 'progress' && item.payload) {
        markProgressSynced(db, item.entity_id, (JSON.parse(item.payload) as LocalProgress).read_at)
      }
      sent++
    }
    catch (error) {
      if (isPermanentFailure(statusOf(error)) || item.retry_count + 1 >= MAX_RETRIES) {
        removeQueued(db, item.id)
        continue
      }
      markRetry(db, item.id)
      break
    }
  }
  return sent
}

export interface BookmarkSyncBody {
  upserts: { id: string, chapter_id: string, paragraph_index: number, note?: string, created_at: string }[]
  deletes: string[]
}

const MAX_BOOKMARK_CHANGES = 500

let chain: Promise<unknown> = Promise.resolve()

/**
 * Runs uploads one after another so the same queued item is never sent twice
 * concurrently (which would, for example, count reading time twice).
 */
function serial<T>(fn: () => Promise<T>): Promise<T> {
  const run = chain.then(fn, fn)
  chain = run.catch(() => {})
  return run
}

function sendBookmarkSync(body: BookmarkSyncBody): Promise<ServerBookmark[]> {
  return apiFetch<ApiResponse<ServerBookmark[]>>('/bookmarks/sync', { method: 'POST', body }).then(r => r.data)
}

/** Builds the sync request from queued bookmark changes (deletes win over upserts). */
export function bookmarkSyncBody(items: SyncQueueItem[]): BookmarkSyncBody {
  const deletes = new Set(items.filter(i => i.action === 'delete').map(i => i.entity_id))
  const upserts: BookmarkSyncBody['upserts'] = []
  for (const item of items) {
    if (item.action !== 'upsert' || deletes.has(item.entity_id) || !item.payload) continue
    const b = JSON.parse(item.payload) as BookmarkSyncBody['upserts'][number]
    upserts.push({
      id: b.id,
      chapter_id: b.chapter_id,
      paragraph_index: b.paragraph_index,
      ...(b.note ? { note: b.note } : {}),
      created_at: b.created_at,
    })
  }
  return { upserts, deletes: [...deletes] }
}

/**
 * Sends queued bookmark changes in one POST /bookmarks/sync and mirrors the
 * full list the server returns. With nothing queued it just pulls the list.
 * Returns false when the request failed (changes stay queued unless rejected
 * permanently).
 */
export async function pushBookmarks(db: SqlDatabase, send = sendBookmarkSync): Promise<boolean> {
  const items = query<SyncQueueItem>(
    db,
    `SELECT id, action, entity_type, entity_id, payload, retry_count FROM local_sync_queue
     WHERE entity_type = 'bookmark' ORDER BY id ASC LIMIT ?`,
    [MAX_BOOKMARK_CHANGES],
  )
  try {
    const server = await send(bookmarkSyncBody(items))
    items.forEach(i => removeQueued(db, i.id))
    replaceBookmarks(db, server)
    return true
  }
  catch (error) {
    const permanent = isPermanentFailure(statusOf(error))
    for (const item of items) {
      if (permanent || item.retry_count + 1 >= MAX_RETRIES) removeQueued(db, item.id)
      else markRetry(db, item.id)
    }
    return false
  }
}

export function useSync() {
  const { getDb, withDb, flush } = useLocalDb()
  const authStore = useAuthStore()
  const syncing = useState('sync:syncing', () => false)
  const lastSyncAt = useState<string | null>('sync:lastSyncAt', () => null)

  function canSync() {
    return import.meta.client && authStore.isLoggedIn && navigator.onLine
  }

  /** Uploads pending local changes, e.g. right after saving progress. */
  function pushPending(): Promise<void> {
    return serial(async () => {
      if (!canSync()) return
      const db = await getDb()
      if (!db) return
      const sent = await pushQueue(db)
      const hasBookmarks = query(db, `SELECT 1 FROM local_sync_queue WHERE entity_type = 'bookmark' LIMIT 1`).length > 0
      const bookmarksSent = hasBookmarks && await pushBookmarks(db)
      if (sent || bookmarksSent) await flush()
    }).catch((error) => {
      console.warn('[sync] push failed', error)
    })
  }

  /** Uploads queued bookmark changes and refreshes the local mirror. */
  function syncBookmarks(): Promise<boolean> {
    return serial(async () => {
      if (!canSync()) return false
      const db = await getDb()
      if (!db) return false
      const ok = await pushBookmarks(db)
      await flush()
      return ok
    })
  }

  async function pullBookshelf() {
    const res = await apiFetch<ApiResponse<LocalBookshelfItem[]>>('/bookshelf')
    await withDb(db => replaceBookshelf(db, res.data))
  }

  async function pullProgress() {
    const res = await apiFetch<ApiResponse<ServerProgress[]>>('/reading-progress')
    // Local rows read more recently than the server's copy are kept (last read wins).
    await withDb(db => res.data.forEach(p => saveProgress(db, p, true)))
  }

  async function syncAll() {
    if (syncing.value || !canSync()) return
    const db = await getDb()
    if (!db) return
    syncing.value = true
    try {
      await serial(() => pushQueue(db))
      await Promise.all([pullBookshelf(), pullProgress(), serial(() => pushBookmarks(db))])
      const now = new Date().toISOString()
      setMeta(db, 'last_sync_at', now)
      lastSyncAt.value = now
      await flush()
    }
    catch (error) {
      console.warn('[sync] failed', error)
    }
    finally {
      syncing.value = false
    }
  }

  async function loadLastSyncAt() {
    const db = await getDb()
    if (db) lastSyncAt.value = getMeta(db, 'last_sync_at')
  }

  return { syncing, lastSyncAt, syncAll, pushPending, syncBookmarks, loadLastSyncAt }
}
