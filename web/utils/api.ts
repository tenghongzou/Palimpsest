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
    return $fetch<T>(`/api/v1${path}`, { ...options, headers }) as Promise<T>
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
