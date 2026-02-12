export const useAuthStore = defineStore('auth', () => {
  const user = ref<any | null>(null)
  const accessToken = ref<string | null>(null)
  const refreshToken = ref<string | null>(null)

  const isLoggedIn = computed(() => !!accessToken.value)
  const isAdmin = computed(() => user.value?.role === 'admin' || user.value?.role === 'super_admin')

  async function login(credentials: { login: string; password: string }) {
    // TODO: POST /api/v1/auth/login
  }

  async function register(data: { username: string; email: string; password: string; nickname: string }) {
    // TODO: POST /api/v1/auth/register
  }

  async function logout() {
    // TODO: POST /api/v1/auth/logout
    user.value = null
    accessToken.value = null
    refreshToken.value = null
  }

  async function refresh() {
    // TODO: POST /api/v1/auth/refresh
  }

  return { user, accessToken, refreshToken, isLoggedIn, isAdmin, login, register, logout, refresh }
})
