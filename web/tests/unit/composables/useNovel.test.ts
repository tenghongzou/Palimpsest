import { describe, it, expect } from 'vitest'
import { NOVEL_SORT_OPTIONS, RANKING_TYPES, novelListParams } from '~/composables/useNovel'

describe('novelListParams', () => {
  it('sends sort_by, not sort', () => {
    expect(novelListParams({ sort_by: 'rating' })).toEqual({ sort_by: 'rating' })
    expect(novelListParams({ sort: 'latest' })).toEqual({ sort_by: 'latest' })
  })

  it('maps the legacy "views" sort to popular and drops unknown sorts', () => {
    expect(novelListParams({ sort: 'views' })).toEqual({ sort_by: 'popular' })
    expect(novelListParams({ sort: 'bogus' })).toEqual({})
  })

  it('uses category_id over the slug', () => {
    expect(novelListParams({ category: 'scifi' })).toEqual({ category: 'scifi' })
    expect(novelListParams({ category: 'scifi', category_id: 10 })).toEqual({ category_id: 10 })
  })

  it('keeps filters and drops empty values and page 1', () => {
    expect(novelListParams({ status: 'completed', language: 'zh-TW', page: 1, page_size: 6 }))
      .toEqual({ status: 'completed', language: 'zh-TW', page_size: 6 })
    expect(novelListParams({ page: 3, status: undefined })).toEqual({ page: 3 })
  })

  it('offers only sort values the API accepts', () => {
    expect(NOVEL_SORT_OPTIONS.map(o => o.value).sort())
      .toEqual(['favorites', 'latest', 'new', 'popular', 'rating', 'words'])
  })

  it('lists the ranking boards the API serves', () => {
    expect(RANKING_TYPES.map(t => t.key)).toEqual(['views', 'favorites', 'rating', 'latest', 'completed'])
  })
})
