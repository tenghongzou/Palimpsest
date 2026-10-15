import { describe, expect, it, vi } from 'vitest'
import {
  RECOMMENDATION_LIMIT,
  SIMILAR_LIMIT,
  fetchRecommendations,
  fetchSimilarNovels,
  latestOnly,
  type RecommendationFetcher,
} from '~/composables/useRecommendations'

const novel = (id: string) => ({ id, title: `Novel ${id}`, author_name: 'A', status: 'ongoing' })

function mockFetcher(data: unknown) {
  const fn = vi.fn().mockResolvedValue({ code: 0, message: 'success', data })
  return { fn, fetcher: fn as unknown as RecommendationFetcher }
}

describe('fetchRecommendations', () => {
  it('requests GET /recommendations with the limit and normalizes the result', async () => {
    const { fn, fetcher } = mockFetcher({
      personalized: true,
      items: [{ novel: novel('a'), reason: { type: 'author', value: 'Lin Yan' } }],
    })
    const list = await fetchRecommendations(fetcher)
    expect(fn).toHaveBeenCalledWith('/recommendations', { params: { limit: RECOMMENDATION_LIMIT } })
    expect(list.personalized).toBe(true)
    expect(list.items).toHaveLength(1)
    expect(list.items[0]!.reason).toEqual({ type: 'author', value: 'Lin Yan' })
  })

  it('reports popular picks as not personalized', async () => {
    const { fetcher } = mockFetcher({ personalized: false, items: [{ novel: novel('a'), reason: { type: 'popular', value: '' } }] })
    expect((await fetchRecommendations(fetcher, 6)).personalized).toBe(false)
  })

  it('propagates errors (the caller hides the section)', async () => {
    const fetcher = vi.fn().mockRejectedValue(Object.assign(new Error('boom'), { status: 500 })) as unknown as RecommendationFetcher
    await expect(fetchRecommendations(fetcher)).rejects.toThrow('boom')
  })
})

describe('fetchSimilarNovels', () => {
  it('requests GET /novels/{id}/similar and leaves out the novel itself', async () => {
    const { fn, fetcher } = mockFetcher([novel('n1'), novel('n2'), novel('n3')])
    const list = await fetchSimilarNovels(fetcher, 'n1')
    expect(fn).toHaveBeenCalledWith('/novels/n1/similar', { params: { limit: SIMILAR_LIMIT } })
    expect(list.map(n => n.id)).toEqual(['n2', 'n3'])
  })

  it('returns an empty list for an empty response', async () => {
    const { fetcher } = mockFetcher([])
    expect(await fetchSimilarNovels(fetcher, 'n1', 3)).toEqual([])
  })
})

describe('latestOnly', () => {
  it('drops the results and errors of requests overtaken by a newer one', async () => {
    const run = latestOnly()
    let resolveFirst!: (v: string) => void
    let rejectSecond!: (e: Error) => void
    const first = run(() => new Promise<string>((resolve) => { resolveFirst = resolve }))
    const second = run(() => new Promise<string>((_, reject) => { rejectSecond = reject }))
    const third = run(() => Promise.resolve('third'))
    resolveFirst('first')
    rejectSecond(new Error('stale'))
    expect(await first).toBeNull()
    expect(await second).toBeNull()
    expect(await third).toBe('third')
  })

  it('rethrows the error of the newest request', async () => {
    const run = latestOnly()
    await expect(run(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail')
  })
})
