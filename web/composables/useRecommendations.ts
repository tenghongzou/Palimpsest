import type { ApiResponse } from '~/utils/api'
import type { Novel } from '~/types/novel'
import {
  normalizeRecommendations,
  normalizeSimilar,
  type ApiRecommendations,
  type RecommendationList,
} from '~/utils/recommendations'

/** Fetches a path from the API and returns its envelope (apiFetch in the app, a mock in tests). */
export type RecommendationFetcher = <T>(path: string, options?: { params?: Record<string, unknown> }) => Promise<T>

export const RECOMMENDATION_LIMIT = 12
export const SIMILAR_LIMIT = 6

export async function fetchRecommendations(fetcher: RecommendationFetcher, limit = RECOMMENDATION_LIMIT): Promise<RecommendationList> {
  const res = await fetcher<ApiResponse<ApiRecommendations>>('/recommendations', { params: { limit } })
  return normalizeRecommendations(res?.data)
}

export async function fetchSimilarNovels(fetcher: RecommendationFetcher, novelId: string, limit = SIMILAR_LIMIT): Promise<Novel[]> {
  const res = await fetcher<ApiResponse<Novel[]>>(`/novels/${encodeURIComponent(novelId)}/similar`, { params: { limit } })
  return normalizeSimilar(res?.data, novelId)
}

/**
 * Keeps only the newest of overlapping requests: `run` resolves to null when
 * a later call started before it finished (e.g. the user logged in meanwhile).
 */
export function latestOnly() {
  let seq = 0
  return async function run<T>(task: () => Promise<T>): Promise<T | null> {
    const mine = ++seq
    try {
      const result = await task()
      return mine === seq ? result : null
    }
    catch (e) {
      if (mine !== seq) return null
      throw e
    }
  }
}

/**
 * Recommendations for the home page. They are per user, so they are fetched in
 * the browser only (never rendered into the ISR-cached HTML) and fetched again
 * when the user logs in or out. Errors leave the list empty, which hides the section.
 */
export function useRecommendations(limit = RECOMMENDATION_LIMIT) {
  const authStore = useAuthStore()
  const items = ref<RecommendationList['items']>([])
  const personalized = ref(false)
  const loading = ref(false)
  const error = ref<unknown>(null)
  const latest = latestOnly()
  let pending = 0

  async function load() {
    pending++
    loading.value = true
    error.value = null
    try {
      const list = await latest(() => fetchRecommendations(apiFetch, limit))
      if (!list) return
      items.value = list.items
      personalized.value = list.personalized
    }
    catch (e) {
      error.value = e
      items.value = []
      personalized.value = false
    }
    finally {
      pending--
      loading.value = pending > 0
    }
  }

  onMounted(() => {
    void load()
    watch(() => [authStore.isLoggedIn, authStore.user?.id] as const, (now, before) => {
      if (now[0] !== before[0] || now[1] !== before[1]) void load()
    })
  })

  return { items, personalized, loading, error, load }
}

/** Novels similar to `novelId` (public; fetched in the browser like the rest of the novel page). */
export function useSimilarNovels(novelId: string, limit = SIMILAR_LIMIT) {
  const novels = ref<Novel[]>([])
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      novels.value = await fetchSimilarNovels(apiFetch, novelId, limit)
    }
    catch {
      novels.value = []
    }
    finally {
      loading.value = false
    }
  }

  onMounted(() => void load())

  return { novels, loading, load }
}
