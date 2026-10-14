import { describe, it, expect } from 'vitest'
import { bookshelfGroups, groupLabel } from '~/composables/useBookshelf'
import { applyLike, normalizeRating } from '~/composables/useCommunity'

describe('bookshelf groups', () => {
  it('lists distinct groups with the default group first', () => {
    const items = [{ group_name: '追更' }, { group_name: 'default' }, { group_name: '追更' }, { group_name: '' }, { group_name: '完結' }]
    expect(bookshelfGroups(items)).toEqual(['default', '完結', '追更'])
  })

  it('labels the default group', () => {
    expect(groupLabel('default')).toBe('預設')
    expect(groupLabel(undefined)).toBe('預設')
    expect(groupLabel('追更')).toBe('追更')
  })
})

describe('community helpers', () => {
  it('rounds ratings to half stars within 0.5..5', () => {
    expect(normalizeRating(3.3)).toBe(3.5)
    expect(normalizeRating(3.2)).toBe(3)
    expect(normalizeRating(0)).toBe(0.5)
    expect(normalizeRating(9)).toBe(5)
    expect(normalizeRating(Number.NaN)).toBe(0.5)
  })

  it('applies a like result', () => {
    const review = { liked_by_me: false, like_count: 2 }
    applyLike(review, { liked: true, like_count: 3 })
    expect(review).toEqual({ liked_by_me: true, like_count: 3 })
  })
})
