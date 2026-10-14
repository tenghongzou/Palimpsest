// Naive UI's component and date-picker locales for the current UI language.
import { dateEnUS, dateZhCN, dateZhTW, enUS, zhCN, zhTW } from 'naive-ui'

const NAIVE_LOCALES = {
  'zh-TW': { locale: zhTW, dateLocale: dateZhTW },
  'zh-CN': { locale: zhCN, dateLocale: dateZhCN },
  'en': { locale: enUS, dateLocale: dateEnUS },
} as const

export function useNaiveLocale() {
  const { locale } = useI18n()
  const current = computed(() => NAIVE_LOCALES[locale.value as keyof typeof NAIVE_LOCALES] ?? NAIVE_LOCALES['zh-TW'])
  return {
    naiveLocale: computed(() => current.value.locale),
    naiveDateLocale: computed(() => current.value.dateLocale),
  }
}
