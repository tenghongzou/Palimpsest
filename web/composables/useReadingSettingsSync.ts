// Keeps the reader store and the server's reading settings in step: when
// logged in, the server copy wins on load and local changes are pushed.
import type { ApiResponse } from '~/utils/api'
import type { ApiReadingSettings } from '~/types/models'
import { fromServerSettings, serverSettingsSaved, toServerSettings } from '~/utils/readingSettings'

const PUSH_DELAY_MS = 800

let applying = false
let pushTimer: ReturnType<typeof setTimeout> | null = null

export function useReadingSettingsSync() {
  const readerStore = useReaderStore()
  const authStore = useAuthStore()

  async function push() {
    if (pushTimer) {
      clearTimeout(pushTimer)
      pushTimer = null
    }
    if (!authStore.isLoggedIn) return
    await apiFetch<ApiResponse<ApiReadingSettings>>('/users/me/reading-settings', {
      method: 'PUT',
      body: toServerSettings(readerStore.settings),
    })
  }

  /** Loads the server settings into the store; uploads local ones if the server has none yet. */
  async function pull() {
    if (!authStore.isLoggedIn) return
    try {
      const res = await apiFetch<ApiResponse<ApiReadingSettings>>('/users/me/reading-settings')
      if (serverSettingsSaved(res.data)) {
        applying = true
        readerStore.replaceSettings(fromServerSettings(res.data))
        await nextTick()
        applying = false
      }
      else {
        await push()
      }
    }
    catch (error) {
      applying = false
      console.warn('[settings] pull failed', error)
    }
  }

  /** Debounced upload after a local change. */
  function schedulePush() {
    if (applying || !authStore.isLoggedIn) return
    if (pushTimer) clearTimeout(pushTimer)
    pushTimer = setTimeout(() => {
      push().catch(error => console.warn('[settings] push failed', error))
    }, PUSH_DELAY_MS)
  }

  return { pull, push, schedulePush }
}
