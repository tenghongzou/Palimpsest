export function useAuth() {
  const authStore = useAuthStore()

  const isLoggedIn = computed(() => authStore.isLoggedIn)
  const user = computed(() => authStore.user)

  async function login(login: string, password: string) {
    return authStore.login({ login, password })
  }

  async function logout() {
    return authStore.logout()
  }

  return { isLoggedIn, user, login, logout }
}
