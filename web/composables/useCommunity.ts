// Reviews, chapter comments, likes and reports.
import type { ApiResponse, Paginated, Pagination } from '~/utils/api'
import type { ApiComment, ApiLikeResult, ApiParagraphCount, ApiReport, ApiReportInput, ApiReview, ApiReviewInput } from '~/types/models'
import { paragraphCountMap, type ParagraphCounts } from '~/utils/paragraphComments'

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

/**
 * True for content held back by automated moderation: it is only public once
 * an admin approves it. List endpoints return the caller's own pending items
 * (never other users'), shown with a 「審核中」 tag and without the public
 * actions (like, reply, report).
 */
export function isPendingModeration(item: { status?: string | null }): boolean {
  return item.status === 'pending'
}

/**
 * The review list with a newly created review on top, replacing a stale copy.
 * Reviews awaiting moderation are listed too: the author sees their own.
 */
export function withCreatedReview(items: ApiReview[], review: ApiReview): { items: ApiReview[], added: boolean } {
  return { items: [review, ...items.filter(r => r.id !== review.id)], added: true }
}

/**
 * The comment list with a newly created comment: replies are appended to
 * their loaded thread, top-level comments go first. Comments awaiting
 * moderation are listed too: the author sees their own. `added` is true for
 * a new top-level comment.
 */
export function withCreatedComment(items: ApiComment[], comment: ApiComment): { items: ApiComment[], added: boolean } {
  const created = { ...comment, replies: comment.replies ?? [] }
  if (created.parent_id) {
    return {
      items: items.map(c => c.id === created.parent_id
        ? { ...c, replies: [...(c.replies ?? []).filter(r => r.id !== created.id), created] }
        : c),
      added: false,
    }
  }
  return { items: [created, ...items.filter(c => c.id !== created.id)], added: true }
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

  /** Posts a review and lists it (pending ones too); check isPendingModeration() on the result before announcing it. */
  async function create(input: ApiReviewInput): Promise<ApiReview> {
    const res = await apiFetch<ApiResponse<ApiReview>>(`/novels/${toValue(novelId)}/reviews`, {
      method: 'POST',
      body: { ...input, rating: normalizeRating(input.rating) },
    })
    const next = withCreatedReview(items.value, res.data)
    items.value = next.items
    if (next.added) pagination.value.total++
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

export interface UseCommentsOptions {
  /** Only list (and post) comments on this paragraph; null for the whole chapter. */
  paragraphIndex?: MaybeRefOrGetter<number | null | undefined>
}

export function useComments(chapterId: MaybeRefOrGetter<string>, options: UseCommentsOptions = {}) {
  const items = ref<ApiComment[]>([])
  const pagination = ref<Pagination>(emptyPagination())
  const sort = ref<CommunitySort>('latest')
  const loading = ref(false)

  const paragraph = () => {
    const p = toValue(options.paragraphIndex)
    return typeof p === 'number' && Number.isInteger(p) && p >= 0 ? p : null
  }

  async function load(page = 1) {
    loading.value = true
    try {
      const p = paragraph()
      const res = await apiFetch<ApiResponse<Paginated<ApiComment>>>(`/chapters/${toValue(chapterId)}/comments`, {
        params: { page, page_size: 20, sort_by: sort.value, ...(p !== null ? { paragraph_index: p } : {}) },
      })
      items.value = res.data.items.map(c => ({ ...c, replies: c.replies ?? [] }))
      pagination.value = res.data.pagination
    }
    finally {
      loading.value = false
    }
  }

  /** Posts a comment or reply and lists it (pending ones too); check isPendingModeration() on the result before announcing it. */
  async function create(input: NewComment): Promise<ApiComment> {
    const p = paragraph()
    // Replies inherit their thread's paragraph on the server.
    const body: NewComment = { ...input, content: input.content.trim() }
    if (!body.parent_id && p !== null) body.paragraph_index = p
    if (body.parent_id) delete body.paragraph_index
    const res = await apiFetch<ApiResponse<ApiComment>>(`/chapters/${toValue(chapterId)}/comments`, {
      method: 'POST',
      body,
    })
    const comment = { ...res.data, replies: res.data.replies ?? [] }
    const next = withCreatedComment(items.value, comment)
    items.value = next.items
    if (next.added) pagination.value.total++
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

/**
 * How many top-level comments each paragraph of a chapter has. `available`
 * is false until counts load (and after a failure, e.g. offline), so the
 * reader can hide its markers.
 */
export function useParagraphCounts(chapterId: MaybeRefOrGetter<string | null | undefined>) {
  const counts = ref<ParagraphCounts>({})
  const available = ref(false)
  let requestId = 0

  async function load(paragraphTotal?: number) {
    const id = toValue(chapterId)
    const current = ++requestId
    if (!id) {
      counts.value = {}
      available.value = false
      return
    }
    try {
      const res = await apiFetch<ApiResponse<ApiParagraphCount[]>>(`/chapters/${id}/comments/paragraph-counts`)
      if (current !== requestId) return
      counts.value = paragraphCountMap(res.data, paragraphTotal)
      available.value = true
    }
    catch {
      if (current !== requestId) return
      counts.value = {}
      available.value = false
    }
  }

  function clear() {
    requestId++
    counts.value = {}
    available.value = false
  }

  return { counts, available, load, clear }
}

/** The thread (top-level comment with its replies) containing a comment or reply. */
export async function fetchCommentThread(commentId: string): Promise<ApiComment> {
  const res = await apiFetch<ApiResponse<ApiComment>>(`/comments/${commentId}`)
  return { ...res.data, replies: res.data.replies ?? [] }
}

export async function submitReport(input: ApiReportInput): Promise<ApiReport> {
  const res = await apiFetch<ApiResponse<ApiReport>>('/reports', { method: 'POST', body: input })
  return res.data
}
