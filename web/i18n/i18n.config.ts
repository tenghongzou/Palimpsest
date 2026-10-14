// Runtime vue-i18n options. Messages live in i18n/locales/*.json and are
// loaded lazily by @nuxtjs/i18n.
export default defineI18nConfig(() => ({
  legacy: false,
  fallbackLocale: 'zh-TW',
  // Missing keys fail the locale key-parity unit test instead of warning at runtime.
  missingWarn: false,
  fallbackWarn: false,
}))
