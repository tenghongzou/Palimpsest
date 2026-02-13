import type { Novel, Chapter, Category } from '~/types/novel'

interface PaginatedResponse<T> {
  items: T[]
  pagination: { page: number; page_size: number; total: number; total_pages: number }
}

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export function useNovel(novelId?: string) {
  const novel = ref<Novel | null>(null)
  const chapters = ref<Chapter[]>([])
  const loading = ref(false)

  async function fetchNovel(id?: string) {
    const targetId = id || novelId
    if (!targetId) return
    loading.value = true
    try {
      const res = await $fetch<ApiResponse<Novel>>(`/api/v1/novels/${targetId}`)
      novel.value = res.data
    }
    finally {
      loading.value = false
    }
  }

  async function fetchChapters(id?: string, order: 'asc' | 'desc' = 'asc') {
    const targetId = id || novelId
    if (!targetId) return
    const res = await $fetch<ApiResponse<Chapter[]>>(`/api/v1/novels/${targetId}/chapters`, {
      params: { order },
    })
    chapters.value = res.data
  }

  if (novelId) {
    onMounted(() => {
      fetchNovel()
      fetchChapters()
    })
  }

  return { novel, chapters, loading, fetchNovel, fetchChapters }
}

export function useNovelList() {
  const novels = ref<Novel[]>([])
  const pagination = ref({ page: 1, page_size: 20, total: 0, total_pages: 0 })
  const loading = ref(false)

  async function fetchNovels(params: Record<string, any> = {}) {
    loading.value = true
    try {
      const res = await $fetch<ApiResponse<PaginatedResponse<Novel>>>('/api/v1/novels', { params })
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
      const res = await $fetch<ApiResponse<Category[]>>('/api/v1/categories')
      categories.value = res.data
    }
    finally {
      loading.value = false
    }
  }

  onMounted(() => fetchCategories())

  return { categories, loading, fetchCategories }
}

export function useRanking() {
  const novels = ref<Novel[]>([])
  const loading = ref(false)

  async function fetchRanking(type: string, period: string = 'weekly', page = 1, pageSize = 20) {
    loading.value = true
    try {
      const res = await $fetch<ApiResponse<PaginatedResponse<Novel>>>(`/api/v1/rankings/${type}`, {
        params: { period, page, page_size: pageSize },
      })
      novels.value = res.data.items
    }
    finally {
      loading.value = false
    }
  }

  return { novels, loading, fetchRanking }
}

export function useSearch() {
  const results = ref<Novel[]>([])
  const hotKeywords = ref<string[]>([])
  const suggestions = ref<string[]>([])
  const loading = ref(false)
  const total = ref(0)

  async function search(query: string, params: Record<string, any> = {}) {
    loading.value = true
    try {
      const res = await $fetch<ApiResponse<{ hits: Novel[]; total: number }>>('/api/v1/search', {
        params: { q: query, ...params },
      })
      results.value = res.data.hits
      total.value = res.data.total
    }
    finally {
      loading.value = false
    }
  }

  async function fetchHotKeywords() {
    const res = await $fetch<ApiResponse<string[]>>('/api/v1/search/hot')
    hotKeywords.value = res.data
  }

  async function fetchSuggestions(query: string) {
    const res = await $fetch<ApiResponse<string[]>>('/api/v1/search/suggestions', {
      params: { q: query },
    })
    suggestions.value = res.data
  }

  return { results, hotKeywords, suggestions, loading, total, search, fetchHotKeywords, fetchSuggestions }
}
