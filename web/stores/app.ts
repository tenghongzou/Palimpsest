// The UI language lives in @nuxtjs/i18n (useI18n / useLanguage), not here.
export const useAppStore = defineStore('app', () => {
  const isOffline = ref(false)
  const isSidebarOpen = ref(false)

  return { isOffline, isSidebarOpen }
})
