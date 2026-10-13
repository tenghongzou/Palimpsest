import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import { SQL_BUILDS, type SqlBuild } from '../sqljsBuilds'
import { pushQueue } from '~/composables/useSync'
import { enqueue, getProgress, migrate, pendingQueue, saveProgress, type SqlDatabase } from '~/utils/localDb'

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
