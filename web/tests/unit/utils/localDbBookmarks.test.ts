import { beforeAll, beforeEach, describe, expect, it } from 'vitest'
import { SQL_BUILDS, type SqlBuild } from '../sqljsBuilds'
import {
  clearUserData,
  enqueue,
  enqueueProgress,
  getProgress,
  listBookmarks,
  markBookmarkDeleted,
  migrate,
  pendingQueue,
  replaceBookmarks,
  saveBookmark,
  saveProgress,
  type LocalBookmark,
  type SqlDatabase,
} from '~/utils/localDb'

describe.each(SQL_BUILDS)('local bookmarks with sql.js $name', (build) => {
  let SQL: Awaited<ReturnType<SqlBuild['open']>>
  let db: SqlDatabase

  beforeAll(async () => {
    SQL = await build.open()
  })

  beforeEach(() => {
    db = new SQL.Database()
    migrate(db)
  })

  const bookmark = (id: string, extra: Partial<LocalBookmark> = {}): Omit<LocalBookmark, 'is_synced'> => ({
    id,
    novel_id: 'n1',
    chapter_id: 'c1',
    chapter_title: '第一章',
    paragraph_index: 3,
    note: null,
    created_at: '2026-10-01T10:00:00.000Z',
    ...extra,
  })

  it('saves and lists bookmarks newest first, filtered by novel and chapter', () => {
    saveBookmark(db, bookmark('a'), false)
    saveBookmark(db, bookmark('b', { created_at: '2026-10-02T10:00:00.000Z', chapter_id: 'c2' }), true)
    saveBookmark(db, bookmark('c', { novel_id: 'n2' }), true)

    expect(listBookmarks(db).map(b => b.id)).toEqual(['b', 'c', 'a'])
    expect(listBookmarks(db, { novelId: 'n1' }).map(b => b.id)).toEqual(['b', 'a'])
    expect(listBookmarks(db, { novelId: 'n1', chapterId: 'c1' }).map(b => b.id)).toEqual(['a'])
    expect(listBookmarks(db, { chapterId: 'c1', novelId: 'n1' })[0])
      .toMatchObject({ paragraph_index: 3, is_synced: 0, chapter_title: '第一章' })
  })

  it('hides deleted bookmarks', () => {
    saveBookmark(db, bookmark('a'), true)
    markBookmarkDeleted(db, 'a')
    expect(listBookmarks(db)).toEqual([])
  })

  it('mirrors the server list but keeps rows with queued changes', () => {
    saveBookmark(db, bookmark('stale'), true)
    saveBookmark(db, bookmark('offline'), false)
    enqueue(db, 'upsert', 'bookmark', 'offline', { id: 'offline' })

    replaceBookmarks(db, [
      { id: 'server', novel_id: 'n1', chapter_id: 'c9', paragraph_index: 1, note: '好段落', created_at: '2026-10-03T00:00:00Z', chapter: { title: '第九章' } },
    ])

    expect(listBookmarks(db).map(b => b.id).sort()).toEqual(['offline', 'server'])
    expect(listBookmarks(db).find(b => b.id === 'server'))
      .toMatchObject({ chapter_title: '第九章', note: '好段落', is_synced: 1 })
  })

  it('does not resurrect a bookmark deleted offline', () => {
    saveBookmark(db, bookmark('a'), true)
    markBookmarkDeleted(db, 'a')
    enqueue(db, 'delete', 'bookmark', 'a', undefined)
    replaceBookmarks(db, [{ id: 'a', novel_id: 'n1', chapter_id: 'c1', paragraph_index: 3 }])
    expect(listBookmarks(db)).toEqual([])
  })

  it('adds up reading time of progress updates waiting in the queue', () => {
    const p = { novel_id: 'n1', chapter_id: 'c1', paragraph_index: 0, scroll_offset: 0, read_at: '2026-10-01T10:00:00.000Z' }
    enqueueProgress(db, { ...p, duration: 40 })
    enqueueProgress(db, { ...p, chapter_id: 'c2', duration: 25 })
    const queue = pendingQueue(db)
    expect(queue).toHaveLength(1)
    expect(JSON.parse(queue[0].payload!)).toMatchObject({ chapter_id: 'c2', duration: 65 })

    enqueueProgress(db, { ...p, duration: 10_000 })
    expect(JSON.parse(pendingQueue(db)[0].payload!).duration).toBe(3600)
  })

  it('clears per-user data on logout', () => {
    saveBookmark(db, bookmark('a'), true)
    saveProgress(db, { novel_id: 'n1', chapter_id: 'c1', paragraph_index: 0, scroll_offset: 0, read_at: '2026-10-01T10:00:00Z' }, true)
    enqueue(db, 'upsert', 'bookmark', 'a', {})
    clearUserData(db)
    expect(listBookmarks(db)).toEqual([])
    expect(pendingQueue(db)).toEqual([])
    expect(getProgress(db, 'n1')).toBeNull()
  })
})
