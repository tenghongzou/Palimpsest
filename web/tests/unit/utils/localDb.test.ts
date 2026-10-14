import { beforeAll, beforeEach, describe, expect, it } from 'vitest'
import { SQL_BUILDS, type SqlBuild } from '../sqljsBuilds'
import {
  cacheSizeBytes,
  cachedChapterList,
  clearChapterCache,
  enforceCacheLimit,
  enqueue,
  getChapter,
  getMeta,
  getProgress,
  listBookshelf,
  markProgressSynced,
  migrate,
  pendingQueue,
  query,
  removeQueued,
  replaceBookshelf,
  saveChapter,
  saveProgress,
  schemaVersion,
  setMeta,
  type SqlDatabase,
} from '~/utils/localDb'
import { SQLITE_MIGRATIONS } from '~/utils/sqliteMigrations'
import { localBookshelf } from '~/composables/useBookshelf'

describe.each(SQL_BUILDS)('localDb with sql.js $name', (build) => {
  let SQL: Awaited<ReturnType<SqlBuild['open']>>
  let db: SqlDatabase

  beforeAll(async () => {
    SQL = await build.open()
  })

  beforeEach(() => {
    db = new SQL.Database()
    migrate(db)
  })

  const chapter = (id: string, content = '內容', novelId = 'n1') => ({
    id, novel_id: novelId, title: `第${id}章`, content, chapter_number: 1, word_count: content.length,
  })

  describe('migrate', () => {
    it('applies the shared schema and records the version', () => {
      expect(schemaVersion(db)).toBe(SQLITE_MIGRATIONS.at(-1)!.version)
      expect(getMeta(db, 'max_cache_size_bytes')).toBe('524288000')
    })

    it('is idempotent', () => {
      expect(() => migrate(db)).not.toThrow()
    })

    it('rolls back a failing migration', () => {
      const fresh = new SQL.Database()
      expect(() => migrate(fresh, [{ version: 1, sql: 'CREATE TABLE a (x); CREATE TABLE broken (' }])).toThrow()
      expect(schemaVersion(fresh)).toBe(0)
      expect(query(fresh, `SELECT name FROM sqlite_master WHERE name = 'a'`)).toHaveLength(0)
    })
  })

  describe('chapters', () => {
    it('saves and reads back a chapter', () => {
      saveChapter(db, chapter('c1', '鬥氣大陸'))
      expect(getChapter(db, 'c1')).toMatchObject({ id: 'c1', content: '鬥氣大陸', novel_id: 'n1' })
      expect(getChapter(db, 'missing')).toBeNull()
    })

    it('lists cached chapters of a novel in order without content', () => {
      saveChapter(db, { ...chapter('c2'), chapter_number: 2 })
      saveChapter(db, { ...chapter('c1'), chapter_number: 1 })
      saveChapter(db, chapter('x', '內容', 'other'))
      const list = cachedChapterList(db, 'n1')
      expect(list.map(c => c.id)).toEqual(['c1', 'c2'])
      expect(list[0]).not.toHaveProperty('content')
    })

    it('measures cache size in UTF-8 bytes', () => {
      saveChapter(db, chapter('c1', '字字')) // 2 CJK chars = 6 bytes
      expect(cacheSizeBytes(db)).toBe(6)
      clearChapterCache(db)
      expect(cacheSizeBytes(db)).toBe(0)
    })

    it('evicts the oldest chapters beyond the cache limit', () => {
      setMeta(db, 'max_cache_size_bytes', '10')
      saveChapter(db, chapter('old', 'aaaaaa'))
      saveChapter(db, chapter('new', 'bbbbbb'))

      expect(enforceCacheLimit(db)).toBe(1)
      expect(getChapter(db, 'old')).toBeNull()
      expect(getChapter(db, 'new')).not.toBeNull()
    })
  })

  describe('progress', () => {
    const base = { novel_id: 'n1', chapter_id: 'c1', paragraph_index: 0, scroll_offset: 0.5 }

    it('keeps the most recently read position', () => {
      saveProgress(db, { ...base, read_at: '2026-10-01T10:00:00Z' }, false)
      saveProgress(db, { ...base, chapter_id: 'c0', read_at: '2026-10-01T09:00:00Z' }, true)
      expect(getProgress(db, 'n1')?.chapter_id).toBe('c1')

      saveProgress(db, { ...base, chapter_id: 'c2', read_at: '2026-10-01T11:00:00+08:00' }, false)
      expect(getProgress(db, 'n1')?.chapter_id).toBe('c1') // 03:00Z is older

      saveProgress(db, { ...base, chapter_id: 'c3', read_at: '2026-10-02T00:00:00Z' }, false)
      expect(getProgress(db, 'n1')).toMatchObject({ chapter_id: 'c3', is_synced: 0 })
    })

    it('marks progress synced only if unchanged since upload', () => {
      saveProgress(db, { ...base, read_at: '2026-10-01T10:00:00Z' }, false)
      markProgressSynced(db, 'n1', '2026-10-01T09:00:00Z')
      expect(getProgress(db, 'n1')?.is_synced).toBe(0)
      markProgressSynced(db, 'n1', '2026-10-01T10:00:00.000Z')
      expect(getProgress(db, 'n1')?.is_synced).toBe(1)
    })
  })

  describe('sync queue', () => {
    it('keeps only the latest change per entity', () => {
      enqueue(db, 'update', 'progress', 'n1', { v: 1 })
      enqueue(db, 'update', 'progress', 'n2', { v: 1 })
      enqueue(db, 'update', 'progress', 'n1', { v: 2 })

      const queue = pendingQueue(db)
      expect(queue.map(q => q.entity_id)).toEqual(['n2', 'n1'])
      expect(JSON.parse(queue[1].payload!)).toEqual({ v: 2 })

      removeQueued(db, queue[0].id)
      expect(pendingQueue(db)).toHaveLength(1)
    })
  })

  describe('bookshelf mirror', () => {
    it('replaces the local copy with server data', () => {
      const novel = { id: 'n1', title: '鬥破蒼穹', author_name: '天蠶土豆' }
      replaceBookshelf(db, [{ novel_id: 'n1', group_name: 'default', added_at: '2026-10-01T00:00:00Z', novel }])
      replaceBookshelf(db, [{ novel_id: 'n1', group_name: 'fav', added_at: '2026-10-01T00:00:00Z', novel }])

      const items = listBookshelf(db)
      expect(items).toHaveLength(1)
      expect(items[0]).toMatchObject({ group_name: 'fav', novel: { title: '鬥破蒼穹' } })
    })

    it('shows the offline bookshelf with the last chapter read on this device', () => {
      const novel = { id: 'n1', title: '鬥破蒼穹', author_name: '天蠶土豆' }
      replaceBookshelf(db, [
        { novel_id: 'n1', group_name: 'fav', added_at: '2026-10-01T00:00:00Z', novel },
        { novel_id: 'n2', group_name: 'default', added_at: '2026-10-02T00:00:00Z', novel: { id: 'n2', title: '凡人修仙傳', author_name: '忘語' } },
      ])
      saveChapter(db, { ...chapter('c3'), chapter_number: 3 })
      saveProgress(db, { novel_id: 'n1', chapter_id: 'c3', paragraph_index: 0, scroll_offset: 0, read_at: '2026-10-03T00:00:00Z' }, true)

      const items = localBookshelf(db)
      const n1 = items.find(i => i.novel_id === 'n1')
      expect(n1).toMatchObject({
        group_name: 'fav',
        has_update: false,
        novel: { title: '鬥破蒼穹' },
        reading_progress: { chapter_id: 'c3', chapter_title: '第c3章', chapter_number: 3 },
      })
      expect(items.find(i => i.novel_id === 'n2')?.reading_progress).toBeNull()
    })
  })
})
