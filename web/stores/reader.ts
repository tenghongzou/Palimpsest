import { DEFAULT_READER_SETTINGS, normalizeSettings, type ReaderSettings } from '~/utils/readingSettings'


export const useReaderStore = defineStore('reader', () => {
  const settings = ref<ReaderSettings>({ ...DEFAULT_READER_SETTINGS })
  const currentChapterId = ref<string | null>(null)

  function updateSettings(partial: Partial<ReaderSettings>) {
    settings.value = normalizeSettings({ ...settings.value, ...partial })
  }

  function replaceSettings(next: ReaderSettings) {
    settings.value = normalizeSettings(next)
  }

  function resetSettings() {
    settings.value = { ...DEFAULT_READER_SETTINGS }
  }

  return { settings, currentChapterId, updateSettings, replaceSettings, resetSettings }
}, {
  persist: {
    pick: ['settings'],
    // Settings saved by older versions may miss fields or use old theme names.
    afterHydrate: (ctx) => {
      ctx.store.settings = normalizeSettings(ctx.store.settings)
    },
  },
})
