// Data sync between local SQLite and server
import { apiFetch, statusOf, type ApiResponse } from '~/utils/api'
import {
  getMeta,
  markProgressSynced,
  markRetry,
  pendingQueue,
  removeQueued,
  replaceBookshelf,
  saveProgress,
  setMeta,
  type LocalBookshelfItem,
  type LocalProgress,
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
  for (const item of pendingQueue(db)) {
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

export function useSync() {
  const { getDb, withDb, flush } = useLocalDb()
  const authStore = useAuthStore()
  const syncing = useState('sync:syncing', () => false)
  const lastSyncAt = useState<string | null>('sync:lastSyncAt', () => null)

  function canSync() {
    return import.meta.client && authStore.isLoggedIn && navigator.onLine
  }

  /** Uploads pending local changes, e.g. right after saving progress. */
  async function pushPending() {
    if (!canSync()) return
    const db = await getDb()
    if (!db) return
    if (await pushQueue(db)) await flush()
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
      await pushQueue(db)
      await Promise.all([pullBookshelf(), pullProgress()])
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

  return { syncing, lastSyncAt, syncAll, pushPending, loadLastSyncAt }
}
