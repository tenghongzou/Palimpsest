interface ReaderSettings {
  fontSize: number
  lineHeight: number
  letterSpacing: number
  margin: number
  fontFamily: string
  theme: 'white' | 'yellow' | 'green' | 'dark' | 'black'
  readingMode: 'scroll' | 'page'
}

const defaultSettings: ReaderSettings = {
  fontSize: 18,
  lineHeight: 1.8,
  letterSpacing: 0,
  margin: 16,
  fontFamily: 'system',
  theme: 'white',
  readingMode: 'scroll',
}

export const useReaderStore = defineStore('reader', () => {
  const settings = ref<ReaderSettings>({ ...defaultSettings })
  const currentChapterId = ref<string | null>(null)

  function updateSettings(partial: Partial<ReaderSettings>) {
    settings.value = { ...settings.value, ...partial }
  }

  function resetSettings() {
    settings.value = { ...defaultSettings }
  }

  return { settings, currentChapterId, updateSettings, resetSettings }
}, {
  persist: {
    pick: ['settings'],
  },
})
