// Client-only plugin: opens the offline database and keeps it in sync with the
// server on startup, after login and whenever the browser comes back online.
export default defineNuxtPlugin((nuxtApp) => {
  const authStore = useAuthStore()
  const { syncAll, loadLastSyncAt } = useSync()

  nuxtApp.hook('app:mounted', () => {
    void loadLastSyncAt()
    void syncAll()
  })

  watch(() => authStore.isLoggedIn, (loggedIn) => {
    if (loggedIn) void syncAll()
  })

  window.addEventListener('online', () => void syncAll())
})
