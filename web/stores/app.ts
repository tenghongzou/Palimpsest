export const useAppStore = defineStore('app', () => {
  const locale = ref<'zh-TW' | 'zh-CN' | 'en'>('zh-TW')
  const isOffline = ref(false)
  const isSidebarOpen = ref(false)

  function setLocale(newLocale: 'zh-TW' | 'zh-CN' | 'en') {
    locale.value = newLocale
  }

  return { locale, isOffline, isSidebarOpen, setLocale }
})
