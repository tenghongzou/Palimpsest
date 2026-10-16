import { describe, expect, it } from 'vitest'
import { isPendingModeration, withCreatedComment, withCreatedReview } from '~/composables/useCommunity'
import type { ApiComment, ApiReview } from '~/types/models'

function review(id: string, status: ApiReview['status'] = 'approved'): ApiReview {
  return { id, user_id: 'u', novel_id: 'n', title: id, content: id, rating: 4, like_count: 0, status, liked_by_me: false }
}

function comment(id: string, extra: Partial<ApiComment> = {}): ApiComment {
  return { id, user_id: 'u', chapter_id: 'c', content: id, like_count: 0, liked_by_me: false, status: 'approved', replies: [], ...extra }
}

describe('pending moderation', () => {
  it('recognises content held for moderation', () => {
    expect(isPendingModeration({ status: 'pending' })).toBe(true)
    expect(isPendingModeration({ status: 'approved' })).toBe(false)
    expect(isPendingModeration({})).toBe(false)
  })

  it('puts a published review on top, replacing a stale copy', () => {
    const items = [review('a'), review('b')]
    const result = withCreatedReview(items, review('b'))
    expect(result.added).toBe(true)
    expect(result.items.map(r => r.id)).toEqual(['b', 'a'])
  })

  it('lists a review awaiting moderation on top for its author', () => {
    const items = [review('a')]
    const result = withCreatedReview(items, review('new', 'pending'))
    expect(result.added).toBe(true)
    expect(result.items.map(r => [r.id, r.status])).toEqual([['new', 'pending'], ['a', 'approved']])
    expect(items.map(r => r.id)).toEqual(['a'])
  })

  it('puts a published comment on top', () => {
    const result = withCreatedComment([comment('a')], comment('new', { replies: undefined }))
    expect(result.added).toBe(true)
    expect(result.items.map(c => c.id)).toEqual(['new', 'a'])
    expect(result.items[0]!.replies).toEqual([])
  })

  it('appends a published reply to its thread without counting it', () => {
    const result = withCreatedComment([comment('a'), comment('b')], comment('r', { parent_id: 'b' }))
    expect(result.added).toBe(false)
    expect(result.items[1]!.replies!.map(r => r.id)).toEqual(['r'])
    expect(result.items[0]!.replies).toEqual([])
  })

  it('lists a comment awaiting moderation on top for its author', () => {
    const items = [comment('a')]
    const result = withCreatedComment(items, comment('new', { status: 'pending', paragraph_index: 2 }))
    expect(result.added).toBe(true)
    expect(result.items.map(c => [c.id, c.status])).toEqual([['new', 'pending'], ['a', 'approved']])
    expect(result.items[0]!.paragraph_index).toBe(2)
  })

  it('appends a pending reply to its thread without counting it', () => {
    const items = [comment('a', { replies: [comment('old', { parent_id: 'a' })] })]
    const reply = withCreatedComment(items, comment('r', { parent_id: 'a', status: 'pending' }))
    expect(reply.added).toBe(false)
    expect(reply.items[0]!.replies!.map(r => [r.id, r.status])).toEqual([['old', 'approved'], ['r', 'pending']])
    expect(items[0]!.replies).toHaveLength(1)
  })

  it('does not duplicate a reply already in its thread', () => {
    const items = [comment('a', { replies: [comment('r', { parent_id: 'a', status: 'pending' })] })]
    const reply = withCreatedComment(items, comment('r', { parent_id: 'a', status: 'pending' }))
    expect(reply.items[0]!.replies!.map(r => r.id)).toEqual(['r'])
  })

  it('leaves the list unchanged for a reply whose thread is not loaded', () => {
    const items = [comment('a')]
    const reply = withCreatedComment(items, comment('r', { parent_id: 'zz', status: 'pending' }))
    expect(reply).toEqual({ items, added: false })
  })
})
