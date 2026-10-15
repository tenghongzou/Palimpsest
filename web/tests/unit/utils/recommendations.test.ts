import { describe, expect, it } from 'vitest'
import { makeT } from '../i18n'
import {
  normalizeReason,
  normalizeRecommendations,
  normalizeSimilar,
  recommendationReasonText,
} from '~/utils/recommendations'

const novel = (id: string, title = `Novel ${id}`) => ({ id, title, author_name: 'A', status: 'ongoing' })

describe('recommendationReasonText', () => {
  it('phrases each reason in zh-TW', () => {
    const t = makeT('zh-TW')
    expect(recommendationReasonText(t, { type: 'category', value: '奇幻' })).toBe('因為你喜歡奇幻')
    expect(recommendationReasonText(t, { type: 'tag', value: '懸疑' })).toBe('你常看的「懸疑」')
    expect(recommendationReasonText(t, { type: 'author', value: '林硯' })).toBe('林硯 的作品')
    expect(recommendationReasonText(t, { type: 'popular', value: '' })).toBe('熱門推薦')
  })

  it('phrases each reason in zh-CN and English', () => {
    expect(recommendationReasonText(makeT('zh-CN'), { type: 'category', value: '科幻' })).toBe('因为你喜欢科幻')
    const en = makeT('en')
    expect(recommendationReasonText(en, { type: 'category', value: 'Fantasy' })).toBe('Because you like Fantasy')
    expect(recommendationReasonText(en, { type: 'tag', value: 'mystery' })).toBe('You often read “mystery”')
    expect(recommendationReasonText(en, { type: 'author', value: 'Lin Yan' })).toBe('More from Lin Yan')
    expect(recommendationReasonText(en, { type: 'popular', value: '' })).toBe('Popular right now')
  })

  it('falls back to "popular" for unknown types and missing names', () => {
    const t = makeT('en')
    expect(recommendationReasonText(t, { type: 'friends' as never, value: 'x' })).toBe('Popular right now')
    expect(recommendationReasonText(t, { type: 'category', value: '  ' })).toBe('Popular right now')
    expect(recommendationReasonText(t, null)).toBe('Popular right now')
  })
})

describe('normalizeReason', () => {
  it('trims names and clears the value of popular reasons', () => {
    expect(normalizeReason({ type: 'tag', value: ' 懸疑 ' })).toEqual({ type: 'tag', value: '懸疑' })
    expect(normalizeReason({ type: 'popular', value: 'ignored' })).toEqual({ type: 'popular', value: '' })
  })
})

describe('normalizeRecommendations', () => {
  it('keeps valid items in order and drops malformed and duplicate ones', () => {
    const list = normalizeRecommendations({
      personalized: true,
      items: [
        { novel: novel('a') as never, reason: { type: 'category', value: '奇幻' } },
        { novel: null as never, reason: { type: 'popular', value: '' } },
        { novel: novel('b') as never, reason: undefined as never },
        { novel: novel('a') as never, reason: { type: 'tag', value: 'x' } },
      ],
    })
    expect(list.personalized).toBe(true)
    expect(list.items.map(i => i.novel.id)).toEqual(['a', 'b'])
    expect(list.items[1]!.reason).toEqual({ type: 'popular', value: '' })
  })

  it('treats a missing or empty response as not personalized and empty', () => {
    expect(normalizeRecommendations(null)).toEqual({ personalized: false, items: [] })
    expect(normalizeRecommendations({ personalized: true, items: [] })).toEqual({ personalized: false, items: [] })
    expect(normalizeRecommendations({ items: 'nope' as never })).toEqual({ personalized: false, items: [] })
  })
})

describe('normalizeSimilar', () => {
  it('drops the novel itself, duplicates and malformed entries', () => {
    const out = normalizeSimilar([novel('self'), novel('x'), { id: 'y' }, novel('x'), novel('z')], 'self')
    expect(out.map(n => n.id)).toEqual(['x', 'z'])
  })

  it('returns an empty list for anything but an array', () => {
    expect(normalizeSimilar(null, 'a')).toEqual([])
    expect(normalizeSimilar({ items: [] }, 'a')).toEqual([])
  })
})
