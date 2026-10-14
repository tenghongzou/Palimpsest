// Applies a signed-in user's `language_pref` as the UI language: on session
// restore (after hydration, so server-rendered markup is not mismatched),
// after login and whenever the account copy changes (e.g. GET /users/me).
import { isSupportedLocale } from '~/i18n/constants'

export default defineNuxtPlugin((nuxtApp) => {
  const authStore = useAuthStore()
  // The module's NuxtApp augmentation does not reach plugins here; this is the part used.
  const i18n = nuxtApp.$i18n as {
    locale: Ref<string>
    t: (key: string, named?: Record<string, unknown>) => string
    setLocale: (locale: string) => Promise<void>
  }

  // Browsers registered as devices get a fallback name in the current UI language.
  setDeviceNameLabels({
    browserOn: os => i18n.t('devices.browserOn', { os }),
    get generic() {
      return i18n.t('devices.webBrowser')
    },
  })

  nuxtApp.hook('app:mounted', () => {
    watch(
      () => (authStore.isLoggedIn ? authStore.user?.language_pref : undefined),
      (pref) => {
        if (isSupportedLocale(pref) && pref !== i18n.locale.value) void i18n.setLocale(pref)
      },
      { immediate: true },
    )
  })
})
