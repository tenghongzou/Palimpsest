// Display formatting bound to the current UI language (see utils/format.ts).
import {
  chapterLabel,
  formatDate,
  formatDateTime,
  formatDuration,
  formatNumber,
  formatRelativeTime,
  formatViewCount,
  formatWordCount,
  novelStatus,
  type FormatContext,
  type Translate,
} from '~/utils/format'

export function useFormat() {
  const { t, locale } = useI18n()
  const translate: Translate = (key, named = {}, plural) =>
    plural === undefined ? t(key, named) : t(key, named, plural)
  const ctx = (): FormatContext => ({ t: translate, locale: locale.value })

  return {
    t: translate,
    formatWordCount: (count: number) => formatWordCount(count, ctx()),
    formatViewCount: (count: number) => formatViewCount(count, ctx()),
    formatNumber: (value: number) => formatNumber(value, locale.value),
    formatRelativeTime: (date: string | Date) => formatRelativeTime(date, ctx()),
    formatDuration: (seconds: number) => formatDuration(seconds, ctx()),
    formatDate: (date: string | Date | null | undefined) => formatDate(date, locale.value),
    formatDateTime: (date: string | Date | null | undefined) => formatDateTime(date, locale.value),
    chapterLabel: (number: number, title: string) => chapterLabel(number, title, ctx()),
    novelStatus: (status: string | undefined) => novelStatus(status, ctx()),
  }
}
