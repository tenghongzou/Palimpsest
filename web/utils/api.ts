// ofetch wrapper for API calls to Go backend
export function useApi() {
  const config = useRuntimeConfig()

  return $fetch.create({
    baseURL: config.public.apiBaseUrl + '/v1',
    headers: {
      'Content-Type': 'application/json',
    },
    onRequest({ options }) {
      const authStore = useAuthStore()
      if (authStore.accessToken) {
        options.headers = {
          ...options.headers,
          Authorization: `Bearer ${authStore.accessToken}`,
        }
      }
    },
    onResponseError({ response }) {
      if (response.status === 401) {
        // TODO: attempt token refresh, then retry
      }
    },
  })
}
