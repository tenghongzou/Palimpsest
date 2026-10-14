// UI languages. These codes match the account's `language_pref` and the
// Flutter app's locales; keep them in step.
export const SUPPORTED_LOCALES = ['zh-TW', 'zh-CN', 'en'] as const
export type AppLocale = typeof SUPPORTED_LOCALES[number]
export const DEFAULT_LOCALE: AppLocale = 'zh-TW'

/** Cookie holding the UI language of anonymous visitors (and the last choice of signed-in ones). */
export const LOCALE_COOKIE = 'palimpsest_locale'

/** Each language's own name, shown in language switchers regardless of the UI language. */
export const LOCALE_NAMES: Record<AppLocale, string> = {
  'zh-TW': '繁體中文',
  'zh-CN': '简体中文',
  'en': 'English',
}

export function isSupportedLocale(value: unknown): value is AppLocale {
  return typeof value === 'string' && (SUPPORTED_LOCALES as readonly string[]).includes(value)
}

/** The BCP 47 tag used for Intl formatting. */
export function intlLocale(locale: string): string {
  return locale === 'en' ? 'en-US' : locale
}
