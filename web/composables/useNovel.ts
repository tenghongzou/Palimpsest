import type { Novel, Chapter, Category } from '~/types/novel'
import type { ApiResponse, Paginated, Pagination } from '~/utils/api'

export type NovelSort = 'latest' | 'popular' | 'rating' | 'words' | 'favorites' | 'new'

export const NOVEL_SORT_OPTIONS: { labelKey: string, value: NovelSort }[] = [
  { labelKey: 'novel.sort.latest', value: 'latest' },
  { labelKey: 'novel.sort.popular', value: 'popular' },
  { labelKey: 'novel.sort.rating', value: 'rating' },
  { labelKey: 'novel.sort.words', value: 'words' },
  { labelKey: 'novel.sort.favorites', value: 'favorites' },
  { labelKey: 'novel.sort.new', value: 'new' },
]

export interface NovelListQuery {
  page?: number
  page_size?: number
  category_id?: number
  /** Category slug; ignored by the API when category_id is given. */
  category?: string
  status?: 'ongoing' | 'completed' | 'hiatus'
  language?: 'zh-TW' | 'zh-CN' | 'en'
  sort_by?: NovelSort
}

const SORT_VALUES = new Set<string>(NOVEL_SORT_OPTIONS.map(o => o.value))

/**
 * Builds GET /novels query params, dropping empty values and mapping the old
 * `sort`/`views` names some links still use to the API's `sort_by` values.
 */
export function novelListParams(query: NovelListQuery & { sort?: string }): Record<string, string | number> {
  const params: Record<string, string | number> = {}
  const rawSort = query.sort_by ?? query.sort
  const sort = rawSort === 'views' ? 'popular' : rawSort
  if (sort && SORT_VALUES.has(sort)) params.sort_by = sort
  if (query.page && query.page > 1) params.page = query.page
  if (query.page_size) params.page_size = query.page_size
  if (query.category_id) params.category_id = query.category_id
  else if (query.category) params.category = query.category
  if (query.status) params.status = query.status
  if (query.language) params.language = query.language
  return params
}

export function useNovel(novelId?: string) {
  const novel = ref<Novel | null>(null)
  const chapters = ref<Chapter[]>([])
  const loading = ref(false)
  const error = ref<unknown>(null)

  async function fetchNovel(id?: string) {
    const targetId = id || novelId
    if (!targetId) return
    loading.value = true
    error.value = null
    try {
      const res = await apiFetch<ApiResponse<Novel>>(`/novels/${targetId}`)
      novel.value = res.data
    }
    catch (err) {
      error.value = err
    }
    finally {
      loading.value = false
    }
  }

  async function fetchChapters(id?: string, order: 'asc' | 'desc' = 'asc') {
    const targetId = id || novelId
    if (!targetId) return
    const res = await apiFetch<ApiResponse<Chapter[]>>(`/novels/${targetId}/chapters`, {
      params: { order },
    })
    chapters.value = res.data
  }

  if (novelId) {
    onMounted(() => {
      fetchNovel()
      fetchChapters().catch(() => {})
    })
  }

  return { novel, chapters, loading, error, fetchNovel, fetchChapters }
}

export function useNovelList() {
  const novels = ref<Novel[]>([])
  const pagination = ref<Pagination>({ page: 1, page_size: 20, total: 0, total_pages: 0 })
  const loading = ref(false)

  async function fetchNovels(query: NovelListQuery = {}) {
    loading.value = true
    try {
      const res = await apiFetch<ApiResponse<Paginated<Novel>>>('/novels', { params: novelListParams(query) })
      novels.value = res.data.items
      pagination.value = res.data.pagination
    }
    finally {
      loading.value = false
    }
  }

  return { novels, pagination, loading, fetchNovels }
}

export function useCategories() {
  const categories = ref<Category[]>([])
  const loading = ref(false)

  async function fetchCategories() {
    loading.value = true
    try {
      const res = await apiFetch<ApiResponse<Category[]>>('/categories')
      categories.value = res.data
    }
    finally {
      loading.value = false
    }
  }

  onMounted(() => fetchCategories())

  return { categories, loading, fetchCategories }
}

export type RankingType = 'views' | 'favorites' | 'rating' | 'latest' | 'completed'
export type RankingPeriod = 'daily' | 'weekly' | 'monthly' | 'all'

export const RANKING_TYPES: { key: RankingType, labelKey: string }[] = [
  { key: 'views', labelKey: 'ranking.types.views' },
  { key: 'favorites', labelKey: 'ranking.types.favorites' },
  { key: 'rating', labelKey: 'ranking.types.rating' },
  { key: 'latest', labelKey: 'ranking.types.latest' },
  { key: 'completed', labelKey: 'ranking.types.completed' },
]

export function useRanking() {
  const novels = ref<Novel[]>([])
  const pagination = ref<Pagination>({ page: 1, page_size: 20, total: 0, total_pages: 0 })
  const loading = ref(false)
  const error = ref<unknown>(null)

  async function fetchRanking(type: RankingType, period: RankingPeriod = 'weekly', page = 1, pageSize = 20) {
    loading.value = true
    error.value = null
    try {
      const res = await apiFetch<ApiResponse<Paginated<Novel>>>(`/rankings/${type}`, {
        params: { period, page, page_size: pageSize },
      })
      novels.value = res.data.items
      pagination.value = res.data.pagination
    }
    catch (err) {
      error.value = err
      novels.value = []
    }
    finally {
      loading.value = false
    }
  }

  return { novels, pagination, loading, error, fetchRanking }
}

export function useSearch() {
  const results = ref<Novel[]>([])
  const hotKeywords = ref<string[]>([])
  const suggestions = ref<string[]>([])
  const loading = ref(false)
  const total = ref(0)

  async function search(query: string, params: Record<string, string | number> = {}) {
    loading.value = true
    try {
      const res = await apiFetch<ApiResponse<{ hits: Novel[], estimated_total?: number }>>('/search/novels', {
        params: { q: query, ...params },
      })
      results.value = res.data.hits
      total.value = res.data.estimated_total ?? res.data.hits.length
    }
    finally {
      loading.value = false
    }
  }

  async function fetchHotKeywords() {
    const res = await apiFetch<ApiResponse<string[]>>('/search/hot-keywords')
    hotKeywords.value = res.data ?? []
  }

  async function fetchSuggestions(query: string) {
    const res = await apiFetch<ApiResponse<string[]>>('/search/suggestions', {
      params: { q: query },
    })
    suggestions.value = res.data ?? []
  }

  return { results, hotKeywords, suggestions, loading, total, search, fetchHotKeywords, fetchSuggestions }
}
