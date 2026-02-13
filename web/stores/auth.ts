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

  async function login(credentials: { login: string; password: string }) {
    const data = await $fetch<{ code: number; data: AuthResponse }>('/api/v1/auth/login', {
      method: 'POST',
      body: credentials,
    })
    setAuth(data.data)
    return data.data
  }

  async function register(form: { username: string; email: string; password: string; nickname: string }) {
    const data = await $fetch<{ code: number; data: AuthResponse }>('/api/v1/auth/register', {
      method: 'POST',
      body: form,
    })
    setAuth(data.data)
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

  async function refresh() {
    if (!refreshToken.value) {
      clearAuth()
      return
    }
    try {
      const data = await $fetch<{ code: number; data: AuthResponse }>('/api/v1/auth/refresh', {
        method: 'POST',
        body: { refresh_token: refreshToken.value },
      })
      setAuth(data.data)
    }
    catch {
      clearAuth()
    }
  }

  return { user, accessToken, refreshToken, isLoggedIn, isAdmin, login, register, logout, refresh, clearAuth }
}, {
  persist: {
    pick: ['user', 'accessToken', 'refreshToken'],
  },
})
