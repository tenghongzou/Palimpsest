import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import { SQL_BUILDS, type SqlBuild } from '../sqljsBuilds'
import { bookmarkSyncBody, pushBookmarks, pushQueue } from '~/composables/useSync'
import {
  enqueue,
  getProgress,
  listBookmarks,
  migrate,
  pendingQueue,
  saveBookmark,
  saveProgress,
  type SqlDatabase,
} from '~/utils/localDb'

describe.each(SQL_BUILDS)('pushQueue with sql.js $name', (build) => {
  let SQL: Awaited<ReturnType<SqlBuild['open']>>
  let db: SqlDatabase

  beforeAll(async () => {
    SQL = await build.open()
  })

  beforeEach(() => {
    db = new SQL.Database()
    migrate(db)
  })

  function queueProgress(novelId: string, readAt = '2026-10-01T10:00:00.000Z') {
    const p = { novel_id: novelId, chapter_id: 'c1', paragraph_index: 0, scroll_offset: 1, read_at: readAt }
    saveProgress(db, p, false)
    enqueue(db, 'update', 'progress', novelId, p)
  }

  const httpError = (status?: number) => Object.assign(new Error('fail'), status ? { response: { status } } : {})

  describe('pushQueue', () => {
    it('uploads queued progress and marks it synced', async () => {
      queueProgress('n1')
      queueProgress('n2')
      const send = vi.fn().mockResolvedValue(undefined)

      expect(await pushQueue(db, send)).toBe(2)
      expect(pendingQueue(db)).toHaveLength(0)
      expect(getProgress(db, 'n1')?.is_synced).toBe(1)
    })

    it('stops at a network error and keeps the remaining items in order', async () => {
      queueProgress('n1')
      queueProgress('n2')
      const send = vi.fn().mockRejectedValueOnce(httpError())

      expect(await pushQueue(db, send)).toBe(0)
      expect(send).toHaveBeenCalledTimes(1)
      const queue = pendingQueue(db)
      expect(queue.map(q => q.entity_id)).toEqual(['n1', 'n2'])
      expect(queue[0].retry_count).toBe(1)
    })

    it('drops items the server permanently rejects', async () => {
      queueProgress('n1')
      queueProgress('n2')
      const send = vi.fn().mockRejectedValueOnce(httpError(400)).mockResolvedValueOnce(undefined)

      expect(await pushQueue(db, send)).toBe(1)
      expect(pendingQueue(db)).toHaveLength(0)
      expect(getProgress(db, 'n1')?.is_synced).toBe(0)
    })

    it('keeps retrying on 429 until the retry limit', async () => {
      queueProgress('n1')
      const send = vi.fn().mockRejectedValue(httpError(429))

      for (let i = 0; i < 4; i++) await pushQueue(db, send)
      expect(pendingQueue(db)[0].retry_count).toBe(4)
      await pushQueue(db, send)
      expect(pendingQueue(db)).toHaveLength(0)
    })
  })
})

describe.each(SQL_BUILDS)('bookmark sync with sql.js $name', (build) => {
  let SQL: Awaited<ReturnType<SqlBuild['open']>>
  let db: SqlDatabase

  beforeAll(async () => {
    SQL = await build.open()
  })

  beforeEach(() => {
    db = new SQL.Database()
    migrate(db)
  })

  const httpError = (status?: number) => Object.assign(new Error('fail'), status ? { response: { status } } : {})

  function addOffline(id: string) {
    const b = { id, novel_id: 'n1', chapter_id: 'c1', chapter_title: 'T', paragraph_index: 2, note: null, created_at: '2026-10-01T00:00:00.000Z' }
    saveBookmark(db, b, false)
    enqueue(db, 'upsert', 'bookmark', id, { id, chapter_id: 'c1', paragraph_index: 2, created_at: b.created_at })
  }

  it('builds one request; a delete cancels an upsert of the same bookmark', () => {
    addOffline('a')
    addOffline('b')
    enqueue(db, 'delete', 'bookmark', 'b', undefined)
    enqueue(db, 'delete', 'bookmark', 'gone', undefined)
    const body = bookmarkSyncBody(pendingQueue(db))
    expect(body.upserts.map(u => u.id)).toEqual(['a'])
    expect(body.upserts[0]).toEqual({ id: 'a', chapter_id: 'c1', paragraph_index: 2, created_at: '2026-10-01T00:00:00.000Z' })
    expect(body.deletes.sort()).toEqual(['b', 'gone'])
  })

  it('sends queued changes and mirrors the returned list', async () => {
    addOffline('a')
    const send = vi.fn().mockResolvedValue([
      { id: 'a', novel_id: 'n1', chapter_id: 'c1', paragraph_index: 2 },
      { id: 'other-device', novel_id: 'n1', chapter_id: 'c3', paragraph_index: 0 },
    ])
    expect(await pushBookmarks(db, send)).toBe(true)
    expect(send).toHaveBeenCalledTimes(1)
    expect(pendingQueue(db)).toEqual([])
    expect(listBookmarks(db).map(b => [b.id, b.is_synced]).sort()).toEqual([['a', 1], ['other-device', 1]])
  })

  it('leaves bookmark changes out of the per-item progress queue', async () => {
    addOffline('a')
    const send = vi.fn().mockResolvedValue(undefined)
    expect(await pushQueue(db, send)).toBe(0)
    expect(send).not.toHaveBeenCalled()
    expect(pendingQueue(db)).toHaveLength(1)
  })

  it('keeps changes queued on network errors and drops them when rejected', async () => {
    addOffline('a')
    expect(await pushBookmarks(db, vi.fn().mockRejectedValue(httpError()))).toBe(false)
    expect(pendingQueue(db)[0].retry_count).toBe(1)
    expect(await pushBookmarks(db, vi.fn().mockRejectedValue(httpError(400)))).toBe(false)
    expect(pendingQueue(db)).toEqual([])
  })
})
