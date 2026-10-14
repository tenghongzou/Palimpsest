import { describe, expect, it } from 'vitest'
import {
  badgeText,
  isUnread,
  mergeById,
  notificationTarget,
  notificationText,
  refreshDue,
  UNREAD_REFRESH_MIN_MS,
} from '~/utils/notifications'
import { chapterLabel } from '~/utils/format'
import { makeT } from '../i18n'

const chapter = '11111111-1111-4111-8111-111111111111'
const novel = '22222222-2222-4222-8222-222222222222'
const comment = '33333333-3333-4333-8333-333333333333'

describe('notificationTarget', () => {
  it('opens the reader at the updated chapter', () => {
    expect(notificationTarget({ type: 'chapter_update', chapter_id: chapter, novel_id: novel })).toEqual({ path: `/read/${chapter}` })
  })

  it('falls back to the novel page when a chapter update names no chapter', () => {
    expect(notificationTarget({ type: 'chapter_update', novel_id: novel })).toEqual({ path: `/novel/${novel}` })
    expect(notificationTarget({ type: 'chapter_update' })).toBeNull()
  })

  it('opens the comments on the replied thread', () => {
    expect(notificationTarget({ type: 'comment_reply', chapter_id: chapter, comment_id: comment, novel_id: novel }))
      .toEqual({ path: `/read/${chapter}`, query: { comment } })
  })

  it('opens the chapter comments when the reply names no thread', () => {
    expect(notificationTarget({ type: 'comment_reply', chapter_id: chapter }))
      .toEqual({ path: `/read/${chapter}`, query: { comments: '1' } })
  })

  it('has no target for system announcements', () => {
    expect(notificationTarget({ type: 'system' })).toBeNull()
    expect(notificationTarget({ type: 'system', novel_id: novel, chapter_id: chapter })).toBeNull()
  })
})

describe('unread count helpers', () => {
  it('formats the badge', () => {
    expect(badgeText(0)).toBe('')
    expect(badgeText(-3)).toBe('')
    expect(badgeText(Number.NaN)).toBe('')
    expect(badgeText(7)).toBe('7')
    expect(badgeText(99)).toBe('99')
    expect(badgeText(100)).toBe('99+')
  })

  it('throttles non-forced refreshes', () => {
    expect(refreshDue(null, 1000)).toBe(true)
    expect(refreshDue(1000, 1000 + UNREAD_REFRESH_MIN_MS - 1)).toBe(false)
    expect(refreshDue(1000, 1000 + UNREAD_REFRESH_MIN_MS)).toBe(true)
    expect(refreshDue(0, 50, 100)).toBe(false)
  })

  it('treats a missing read_at as unread', () => {
    expect(isUnread({ read_at: null })).toBe(true)
    expect(isUnread({ read_at: '2026-10-14T00:00:00Z' })).toBe(false)
  })

  it('merges pages without duplicates', () => {
    const a = [{ id: '1' }, { id: '2' }]
    expect(mergeById(a, [{ id: '2' }, { id: '3' }]).map(i => i.id)).toEqual(['1', '2', '3'])
  })
})

describe('notificationText', () => {
  const ctx = (locale: string) => {
    const t = makeT(locale)
    return { t, chapterLabel: (n: number, title: string) => chapterLabel(n, title, { t }) }
  }
  const update = {
    type: 'chapter_update' as const,
    title: '《霧港燈塔》有新章節',
    body: '更新至：歸港',
    params: { novel: '霧港燈塔', chapter: '歸港', chapter_number: '4' },
  }

  it('writes chapter updates in the UI language', () => {
    expect(notificationText(update, ctx('en'))).toEqual({ title: 'New chapters in 霧港燈塔', body: 'Updated to Chapter 4: 歸港' })
    expect(notificationText(update, ctx('zh-CN')).title).toBe('《霧港燈塔》有新章节')
    // Titles that carry their own number are kept as they are.
    const numbered = { ...update, params: { ...update.params, chapter: '第四章 歸港' } }
    expect(notificationText(numbered, ctx('zh-TW')).body).toBe('更新至：第四章 歸港')
  })

  it('names the replier and keeps the comment excerpt', () => {
    const reply = { type: 'comment_reply' as const, title: '小明 回覆了你的留言', body: '我也這麼覺得', params: { actor: '小明' } }
    expect(notificationText(reply, ctx('en'))).toEqual({ title: '小明 replied to your comment', body: '我也這麼覺得' })
  })

  it('falls back to the server text without params', () => {
    const system = { type: 'system' as const, title: '系統維護', body: '今晚 23:00' }
    expect(notificationText(system, ctx('en'))).toEqual({ title: '系統維護', body: '今晚 23:00' })
    expect(notificationText({ ...update, params: undefined }, ctx('en'))).toEqual({ title: update.title, body: update.body })
  })
})
