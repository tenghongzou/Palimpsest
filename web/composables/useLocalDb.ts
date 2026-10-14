// sql.js (WebAssembly SQLite) for offline reading support. The database lives
// in memory and is persisted to IndexedDB as a single blob.
import { migrate, type SqlDatabase } from '~/utils/localDb'

const IDB_NAME = 'palimpsest'
const IDB_STORE = 'sqlite'
const IDB_KEY = 'local.db'
const PERSIST_DELAY_MS = 1000

let dbPromise: Promise<SqlDatabase | null> | null = null
let persistTimer: ReturnType<typeof setTimeout> | null = null
let dirty = false

function idbRequest<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    const open = indexedDB.open(IDB_NAME, 1)
    open.onupgradeneeded = () => open.result.createObjectStore(IDB_STORE)
    open.onerror = () => reject(open.error)
    open.onsuccess = () => {
      const idb = open.result
      const req = run(idb.transaction(IDB_STORE, mode).objectStore(IDB_STORE))
      req.onsuccess = () => {
        resolve(req.result)
        idb.close()
      }
      req.onerror = () => {
        reject(req.error)
        idb.close()
      }
    }
  })
}

async function openDb(): Promise<SqlDatabase | null> {
  if (!import.meta.client || typeof indexedDB === 'undefined') return null
  try {
    const [{ default: initSqlJs }, { default: wasmUrl }] = await Promise.all([
      import('sql.js'),
      import('sql.js/dist/sql-wasm-browser.wasm?url'),
    ])
    const SQL = await initSqlJs({ locateFile: () => wasmUrl })
    const saved = await idbRequest<Uint8Array | undefined>('readonly', s => s.get(IDB_KEY)).catch(() => undefined)

    let db: SqlDatabase
    try {
      db = new SQL.Database(saved) as SqlDatabase
      migrate(db)
    }
    catch (error) {
      // A corrupt or incompatible saved database only holds cache data; start over.
      console.warn('[localDb] discarding unreadable local database', error)
      db = new SQL.Database() as SqlDatabase
      migrate(db)
      dirty = true
    }

    window.addEventListener('pagehide', () => void flushLocalDb())
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') void flushLocalDb()
    })
    return db
  }
  catch (error) {
    console.warn('[localDb] offline storage unavailable', error)
    return null
  }
}

function getDb(): Promise<SqlDatabase | null> {
  dbPromise ??= openDb()
  return dbPromise
}

/** Writes the database to IndexedDB now if it has unsaved changes. */
export async function flushLocalDb() {
  if (persistTimer) {
    clearTimeout(persistTimer)
    persistTimer = null
  }
  if (!dirty || !dbPromise) return
  const db = await dbPromise
  if (!db) return
  dirty = false
  try {
    const data = db.export()
    await idbRequest('readwrite', s => s.put(data, IDB_KEY))
  }
  catch (error) {
    dirty = true
    console.warn('[localDb] failed to persist local database', error)
  }
}

function schedulePersist() {
  dirty = true
  if (persistTimer) clearTimeout(persistTimer)
  persistTimer = setTimeout(() => void flushLocalDb(), PERSIST_DELAY_MS)
}

export function useLocalDb() {
  /**
   * Runs fn against the local database and schedules persistence. Resolves to
   * null when offline storage is unavailable (SSR, private mode, old browsers).
   */
  async function withDb<T>(fn: (db: SqlDatabase) => T): Promise<T | null> {
    const db = await getDb()
    if (!db) return null
    const result = fn(db)
    schedulePersist()
    return result
  }

  /** Read-only access that does not mark the database dirty. */
  async function readDb<T>(fn: (db: SqlDatabase) => T): Promise<T | null> {
    const db = await getDb()
    return db ? fn(db) : null
  }

  return { getDb, withDb, readDb, flush: flushLocalDb }
}
