import type { User, AuthResponse } from '~/types/user'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const accessToken = ref<string | null>(null)
  const refreshToken = ref<string | null>(null)

  const isLoggedIn = computed(() => !!accessToken.value)
  const isAdmin = computed(() => user.value?.role === 'admin' || user.value?.role === 'super_admin')

  function setAuth(data: AuthResponse) {
    user.value = data.user
    accessToken.value = data.access_token
    refreshToken.value = data.refresh_token
  }

  function clearAuth() {
    user.value = null
    accessToken.value = null
    refreshToken.value = null
  }

  function setUser(next: User) {
    user.value = next
  }

  /** Refreshes the cached user from GET /users/me. Returns null on failure. */
  async function fetchMe(): Promise<User | null> {
    if (!accessToken.value) return null
    try {
      const res = await apiFetch<{ code: number; data: User }>('/users/me')
      user.value = res.data
      return res.data
    }
    catch {
      return null
    }
  }

  async function login(credentials: { login: string; password: string }) {
    const data = await $fetch<{ code: number; data: AuthResponse }>('/api/v1/auth/login', {
      method: 'POST',
      body: credentials,
    })
    setAuth(data.data)
    await fetchMe()
    return data.data
  }

  async function register(form: { username: string; email: string; password: string; nickname: string }) {
    const data = await $fetch<{ code: number; data: AuthResponse }>('/api/v1/auth/register', {
      method: 'POST',
      body: form,
    })
    setAuth(data.data)
    await fetchMe()
    return data.data
  }

  async function logout() {
    try {
      await $fetch('/api/v1/auth/logout', {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken.value}` },
      })
    }
    catch {}
    clearAuth()
  }

  /** Exchanges the refresh token for a new session. Returns false (and logs out) on failure. */
  async function refresh(): Promise<boolean> {
    if (!refreshToken.value) {
      clearAuth()
      return false
    }
    try {
      const data = await $fetch<{ code: number; data: AuthResponse }>('/api/v1/auth/refresh', {
        method: 'POST',
        body: { refresh_token: refreshToken.value },
      })
      setAuth(data.data)
      return true
    }
    catch {
      clearAuth()
      return false
    }
  }

  return { user, accessToken, refreshToken, isLoggedIn, isAdmin, login, register, logout, refresh, clearAuth, setUser, fetchMe }
}, {
  persist: {
    pick: ['user', 'accessToken', 'refreshToken'],
  },
})
