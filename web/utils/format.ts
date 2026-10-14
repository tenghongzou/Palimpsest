// Locale-aware display formatting. The functions take the UI translator and
// locale explicitly so they stay pure; components use useFormat(), which binds them.
import { intlLocale } from '~/i18n/constants'

/** vue-i18n's `t` (named interpolation; a number as the third argument selects the plural form). */
export type Translate = (key: string, named?: Record<string, unknown>, plural?: number) => string

export interface FormatContext {
  t: Translate
  locale: string
}

function isChinese(locale: string): boolean {
  return locale.startsWith('zh')
}

/** 12345 → "1.2 萬" / "1.2 万" / "12.3K". */
export function formatCompactNumber(count: number, { t, locale }: FormatContext): string {
  const n = Number.isFinite(count) ? count : 0
  if (isChinese(locale)) {
    if (n >= 100000000) return t('format.hundredMillion', { n: (n / 100000000).toFixed(1) })
    if (n >= 10000) return t('format.tenThousand', { n: (n / 10000).toFixed(1) })
    return String(n)
  }
  return new Intl.NumberFormat(intlLocale(locale), { notation: 'compact', maximumFractionDigits: 1 }).format(n)
}

export function formatWordCount(count: number, ctx: FormatContext): string {
  const n = Number.isFinite(count) ? count : 0
  if (isChinese(ctx.locale) && n >= 10000) return ctx.t('format.tenThousandWords', { n: (n / 10000).toFixed(1) })
  return ctx.t('format.words', { n: n >= 10000 ? formatCompactNumber(n, ctx) : formatNumber(n, ctx.locale) }, n)
}

export function formatViewCount(count: number, ctx: FormatContext): string {
  return formatCompactNumber(count, ctx)
}

export function formatNumber(value: number, locale: string): string {
  return new Intl.NumberFormat(intlLocale(locale)).format(Number.isFinite(value) ? value : 0)
}

/** "剛剛", "5 分鐘前", "3 days ago" … then a date after 30 days. */
export function formatRelativeTime(date: string | Date, ctx: FormatContext, now: Date = new Date()): string {
  const target = new Date(date)
  if (Number.isNaN(target.getTime())) return ''
  const diffMs = now.getTime() - target.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHrs = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return ctx.t('format.justNow')
  const rtf = new Intl.RelativeTimeFormat(intlLocale(ctx.locale), { numeric: 'always' })
  if (diffMins < 60) return rtf.format(-diffMins, 'minute')
  if (diffHrs < 24) return rtf.format(-diffHrs, 'hour')
  if (diffDays < 30) return rtf.format(-diffDays, 'day')
  return formatDate(target, ctx.locale)
}

export type NovelStatus = 'ongoing' | 'completed' | 'hiatus'

export const NOVEL_STATUS_TYPES: Record<NovelStatus, 'success' | 'warning' | 'info'> = {
  ongoing: 'success',
  completed: 'info',
  hiatus: 'warning',
}

export function novelStatus(status: string | undefined, { t }: Pick<FormatContext, 't'>): { label: string, type: 'success' | 'warning' | 'info' } | null {
  if (!status || !(status in NOVEL_STATUS_TYPES)) return null
  return { label: t(`novel.status.${status}`), type: NOVEL_STATUS_TYPES[status as NovelStatus] }
}

/** Seconds as "N 小時 M 分鐘" / "M 分鐘" (or the locale's equivalent). */
export function formatDuration(seconds: number, { t }: Pick<FormatContext, 't'>): string {
  const s = Math.max(0, Math.floor(seconds || 0))
  const hours = Math.floor(s / 3600)
  const minutes = Math.floor((s % 3600) / 60)
  if (hours > 0) {
    return minutes
      ? t('format.hoursMinutes', { h: hours, m: minutes }, hours)
      : t('format.hours', { h: hours }, hours)
  }
  return t('format.minutes', { m: minutes }, minutes)
}

export function formatDate(date: string | Date | null | undefined, locale: string): string {
  if (!date) return ''
  const d = new Date(date)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleDateString(intlLocale(locale))
}

export function formatDateTime(date: string | Date | null | undefined, locale: string): string {
  if (!date) return ''
  const d = new Date(date)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleString(intlLocale(locale), { hour12: false, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

// Matches chapter numbering in the novel's own text (content, not UI copy).
const NUMBERED_TITLE = /^\s*第\s*[0-9０-９零〇一二兩两三四五六七八九十百千萬万]+\s*[章回節节卷]|^\s*chapter\s+\d+/i

/** A chapter's label in lists: "第3章 標題" / "Chapter 3: Title", unless the title already carries its own number. */
export function chapterLabel(number: number, title: string, { t }: Pick<FormatContext, 't'>): string {
  if (NUMBERED_TITLE.test(title)) return title
  return title ? t('format.chapterWithTitle', { n: number, title }) : t('format.chapter', { n: number })
}
