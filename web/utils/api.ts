export interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

type ApiFetchOptions = NonNullable<Parameters<typeof $fetch>[1]>

// Concurrent 401s share one refresh request instead of each starting their own.
let refreshing: Promise<boolean> | null = null

export function refreshSession(): Promise<boolean> {
  if (!refreshing) {
    const authStore = useAuthStore()
    refreshing = authStore.refresh().finally(() => {
      refreshing = null
    })
  }
  return refreshing
}

export function statusOf(error: unknown): number | undefined {
  const e = error as { status?: number, statusCode?: number, response?: { status?: number } }
  return e?.response?.status ?? e?.status ?? e?.statusCode
}

/**
 * Calls the Go API through the BFF (`/api/v1` + path) with the current access
 * token. On 401 it refreshes the session once and retries the request.
 */
export async function apiFetch<T>(path: string, options: ApiFetchOptions = {}): Promise<T> {
  const authStore = useAuthStore()

  const send = () => {
    const headers = new Headers(options.headers as HeadersInit | undefined)
    if (authStore.accessToken) {
      headers.set('Authorization', `Bearer ${authStore.accessToken}`)
    }
    // ofetch retries GETs on 429/500/503 by default; retrying a rate limited
    // or unavailable endpoint immediately only burns more quota.
    return $fetch<T>(`/api/v1${path}`, { retryStatusCodes: [408, 502, 504], ...options, headers }) as Promise<T>
  }

  try {
    return await send()
  }
  catch (error) {
    if (statusOf(error) !== 401 || !authStore.refreshToken) {
      throw error
    }
    if (!(await refreshSession())) {
      throw error
    }
    return await send()
  }
}

export interface Pagination {
  page: number
  page_size: number
  total: number
  total_pages: number
}

export interface Paginated<T> {
  items: T[]
  pagination: Pagination
}

/** The `message` of an API error envelope, or `fallback`. */
export function errorMessage(error: unknown, fallback: string): string {
  const e = error as { data?: { message?: unknown } }
  const msg = e?.data?.message
  return typeof msg === 'string' && msg ? msg : fallback
}

/** Uploads a single file as multipart/form-data under `field`. */
export function apiUpload<T>(path: string, field: string, file: File | Blob, options: ApiFetchOptions = {}): Promise<T> {
  const body = new FormData()
  body.append(field, file)
  return apiFetch<T>(path, { ...options, method: 'POST', body })
}

/**
 * A user-facing (Traditional Chinese) message for a failed request: the entry
 * for its HTTP status in `byStatus`, common defaults, or `fallback`. Backend
 * messages are English, so they are not shown directly.
 */
export function describeError(error: unknown, byStatus: Record<number, string>, fallback: string): string {
  const status = statusOf(error)
  if (status !== undefined && byStatus[status]) return byStatus[status]
  if (status === 429) return '操作太頻繁，請稍後再試'
  if (status === 401) return '登入已過期，請重新登入'
  if (status === 403) return '沒有權限執行此操作'
  if (status === undefined || status === 0) return '無法連線到伺服器，請檢查網路'
  return fallback
}
