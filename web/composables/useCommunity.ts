// Reviews, chapter comments, likes and reports.
import type { ApiResponse, Paginated, Pagination } from '~/utils/api'
import type { ApiComment, ApiLikeResult, ApiReport, ApiReportInput, ApiReview, ApiReviewInput } from '~/types/models'

export type CommunitySort = 'latest' | 'popular'

function emptyPagination(): Pagination {
  return { page: 1, page_size: 20, total: 0, total_pages: 0 }
}

/** Applies a like/unlike result to an item in place. */
export function applyLike<T extends { liked_by_me: boolean, like_count: number }>(item: T, result: ApiLikeResult) {
  item.liked_by_me = result.liked
  item.like_count = result.like_count
}

/** Rounds a rating to the nearest half star within 0.5..5. */
export function normalizeRating(value: number | null | undefined): number {
  const n = Number(value)
  if (!Number.isFinite(n)) return 0.5
  return Math.min(5, Math.max(0.5, Math.round(n * 2) / 2))
}

export function useReviews(novelId: MaybeRefOrGetter<string>) {
  const authStore = useAuthStore()
  const items = ref<ApiReview[]>([])
  const pagination = ref<Pagination>(emptyPagination())
  const sort = ref<CommunitySort>('latest')
  const loading = ref(false)

  /** The signed-in user's review, if it is on the loaded page. */
  const myReview = computed(() => items.value.find(r => r.user_id === authStore.user?.id) ?? null)

  async function load(page = 1) {
    loading.value = true
    try {
      const res = await apiFetch<ApiResponse<Paginated<ApiReview>>>(`/novels/${toValue(novelId)}/reviews`, {
        params: { page, page_size: 10, sort_by: sort.value },
      })
      items.value = res.data.items
      pagination.value = res.data.pagination
    }
    finally {
      loading.value = false
    }
  }

  async function create(input: ApiReviewInput): Promise<ApiReview> {
    const res = await apiFetch<ApiResponse<ApiReview>>(`/novels/${toValue(novelId)}/reviews`, {
      method: 'POST',
      body: { ...input, rating: normalizeRating(input.rating) },
    })
    items.value = [res.data, ...items.value.filter(r => r.id !== res.data.id)]
    pagination.value.total++
    return res.data
  }

  async function update(id: string, input: ApiReviewInput): Promise<ApiReview> {
    const res = await apiFetch<ApiResponse<ApiReview>>(`/reviews/${id}`, {
      method: 'PUT',
      body: { ...input, rating: normalizeRating(input.rating) },
    })
    items.value = items.value.map(r => r.id === id ? { ...r, ...res.data } : r)
    return res.data
  }

  async function remove(id: string) {
    await apiFetch(`/reviews/${id}`, { method: 'DELETE' })
    items.value = items.value.filter(r => r.id !== id)
    pagination.value.total = Math.max(0, pagination.value.total - 1)
  }

  async function toggleLike(review: ApiReview) {
    const res = await apiFetch<ApiResponse<ApiLikeResult>>(`/reviews/${review.id}/like`, {
      method: review.liked_by_me ? 'DELETE' : 'POST',
    })
    applyLike(review, res.data)
  }

  return { items, pagination, sort, loading, myReview, load, create, update, remove, toggleLike }
}

export interface NewComment {
  content: string
  parent_id?: string
  paragraph_index?: number
}

export function useComments(chapterId: MaybeRefOrGetter<string>) {
  const items = ref<ApiComment[]>([])
  const pagination = ref<Pagination>(emptyPagination())
  const sort = ref<CommunitySort>('latest')
  const loading = ref(false)

  async function load(page = 1) {
    loading.value = true
    try {
      const res = await apiFetch<ApiResponse<Paginated<ApiComment>>>(`/chapters/${toValue(chapterId)}/comments`, {
        params: { page, page_size: 20, sort_by: sort.value },
      })
      items.value = res.data.items.map(c => ({ ...c, replies: c.replies ?? [] }))
      pagination.value = res.data.pagination
    }
    finally {
      loading.value = false
    }
  }

  async function create(input: NewComment): Promise<ApiComment> {
    const res = await apiFetch<ApiResponse<ApiComment>>(`/chapters/${toValue(chapterId)}/comments`, {
      method: 'POST',
      body: { ...input, content: input.content.trim() },
    })
    const comment = { ...res.data, replies: res.data.replies ?? [] }
    if (comment.parent_id) {
      const parent = items.value.find(c => c.id === comment.parent_id)
      if (parent) parent.replies = [...(parent.replies ?? []), comment]
    }
    else {
      items.value = [comment, ...items.value]
      pagination.value.total++
    }
    return comment
  }

  async function remove(comment: ApiComment) {
    await apiFetch(`/comments/${comment.id}`, { method: 'DELETE' })
    if (comment.parent_id) {
      const parent = items.value.find(c => c.id === comment.parent_id)
      if (parent) parent.replies = (parent.replies ?? []).filter(r => r.id !== comment.id)
    }
    else {
      items.value = items.value.filter(c => c.id !== comment.id)
      pagination.value.total = Math.max(0, pagination.value.total - 1)
    }
  }

  async function toggleLike(comment: ApiComment) {
    const res = await apiFetch<ApiResponse<ApiLikeResult>>(`/comments/${comment.id}/like`, {
      method: comment.liked_by_me ? 'DELETE' : 'POST',
    })
    applyLike(comment, res.data)
  }

  return { items, pagination, sort, loading, load, create, remove, toggleLike }
}

export async function submitReport(input: ApiReportInput): Promise<ApiReport> {
  const res = await apiFetch<ApiResponse<ApiReport>>('/reports', { method: 'POST', body: input })
  return res.data
}
