// Switching the UI language. The account's `language_pref` is the source of
// truth for signed-in users (applied on login by plugins/locale.client.ts);
// anonymous visitors keep their choice in the locale cookie.
import type { ApiResponse } from '~/utils/api'
import type { User } from '~/types/user'
import { LOCALE_NAMES, SUPPORTED_LOCALES, isSupportedLocale, type AppLocale } from '~/i18n/constants'

/** 'local': cookie only (signed out); 'saved': also stored on the account; 'failed': the account update failed. */
export type LanguageChangeResult = 'local' | 'saved' | 'failed'

export const UI_LANGUAGE_OPTIONS = SUPPORTED_LOCALES.map(code => ({ label: LOCALE_NAMES[code], value: code }))

export function useLanguage() {
  const { locale, setLocale } = useI18n()
  const authStore = useAuthStore()

  const current = computed(() => locale.value as AppLocale)

  async function changeLanguage(code: string): Promise<LanguageChangeResult> {
    if (!isSupportedLocale(code)) return 'local'
    if (code !== locale.value) await setLocale(code)
    if (!authStore.isLoggedIn) return 'local'
    if (authStore.user?.language_pref === code) return 'saved'
    try {
      const res = await apiFetch<ApiResponse<User>>('/users/me', { method: 'PATCH', body: { language_pref: code } })
      authStore.setUser(res.data)
      return 'saved'
    }
    catch {
      return 'failed'
    }
  }

  return { locale: current, options: UI_LANGUAGE_OPTIONS, changeLanguage }
}
