// Client-only: refreshes the signed-in user, keeps reading settings synced and
// clears per-user offline data on logout.
import { clearUserData } from '~/utils/localDb'

export default defineNuxtPlugin((nuxtApp) => {
  const authStore = useAuthStore()
  const readerStore = useReaderStore()
  const { pull, schedulePush } = useReadingSettingsSync()
  const { withDb } = useLocalDb()

  nuxtApp.hook('app:mounted', () => {
    if (authStore.isLoggedIn) {
      void authStore.fetchMe()
      void pull()
    }
  })

  watch(() => authStore.isLoggedIn, (loggedIn, wasLoggedIn) => {
    if (loggedIn) void pull()
    else if (wasLoggedIn) void withDb(db => clearUserData(db))
  })

  watch(() => readerStore.settings, () => schedulePush(), { deep: true })
})
