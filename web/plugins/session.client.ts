// Client-only: refreshes the signed-in user, registers this browser as a
// device, keeps reading settings synced and clears per-user data on logout.
import { clearUserData } from '~/utils/localDb'

export default defineNuxtPlugin((nuxtApp) => {
  const authStore = useAuthStore()
  const readerStore = useReaderStore()
  const { pull, schedulePush } = useReadingSettingsSync()
  const { withDb } = useLocalDb()
  const notificationsStore = useNotificationsStore()

  nuxtApp.hook('app:mounted', () => {
    if (authStore.isLoggedIn) {
      void authStore.fetchMe().then(() => ensureDeviceRegistered())
      void pull()
    }
  })

  watch(() => authStore.isLoggedIn, (loggedIn, wasLoggedIn) => {
    if (loggedIn) {
      void pull()
      // A fresh sign-in: register this browser and fetch the unread count now.
      void ensureDeviceRegistered(true)
      void notificationsStore.refresh({ force: true })
    }
    else if (wasLoggedIn) {
      notificationsStore.reset()
      void withDb(db => clearUserData(db))
    }
  })

  watch(() => readerStore.settings, () => schedulePush(), { deep: true })
})
