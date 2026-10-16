// Transforms for the admin dashboard charts (GET /admin/stats/trends etc.).
import type { components } from '~/types/api'

type AdminTrendDay = components['schemas']['AdminTrendDay']

export const TREND_RANGES = [7, 30, 90] as const
export const TOP_NOVEL_RANGES = [1, 7, 30] as const
export type TrendRange = typeof TREND_RANGES[number]
export type TopNovelRange = typeof TOP_NOVEL_RANGES[number]

/** Series drawn as small multiples (one line chart each). */
export const ACTIVITY_SERIES = ['active_readers', 'reads', 'new_users', 'reading_hours'] as const
/** Series drawn together as grouped columns. */
export const ENGAGEMENT_SERIES = ['new_reviews', 'new_comments', 'bookshelf_adds'] as const
export type TrendSeriesKey = typeof ACTIVITY_SERIES[number] | typeof ENGAGEMENT_SERIES[number]

/** Colours readable on light and dark backgrounds. */
export const SERIES_COLORS: Record<TrendSeriesKey, string> = {
  active_readers: '#1890ff',
  reads: '#13a8a8',
  new_users: '#52c41a',
  reading_hours: '#fa8c16',
  new_reviews: '#722ed1',
  new_comments: '#eb2f96',
  bookshelf_adds: '#1890ff',
}

/** Reading seconds as hours with one decimal. */
export function secondsToHours(seconds: number): number {
  return Math.round((Number(seconds) || 0) / 360) / 10
}

/** One day's value for a series; reading time is converted to hours. */
export function seriesValue(day: AdminTrendDay, key: TrendSeriesKey): number {
  if (key === 'reading_hours') return secondsToHours(day.reading_seconds)
  return Number(day[key]) || 0
}

/** The values of a series, oldest day first. */
export function seriesValues(days: AdminTrendDay[], key: TrendSeriesKey): number[] {
  return days.map(d => seriesValue(d, key))
}

/** Sum of a series over the period (hours keep one decimal). */
export function seriesTotal(days: AdminTrendDay[], key: TrendSeriesKey): number {
  if (key === 'reading_hours') return secondsToHours(days.reduce((sum, d) => sum + (Number(d.reading_seconds) || 0), 0))
  return seriesValues(days, key).reduce((a, b) => a + b, 0)
}

/** True when the period has no activity at all (every series is zero). */
export function isQuietPeriod(days: AdminTrendDay[]): boolean {
  const keys: TrendSeriesKey[] = [...ACTIVITY_SERIES, ...ENGAGEMENT_SERIES]
  return days.every(d => keys.every(k => seriesValue(d, k) === 0))
}

/** "MM/DD" for an API date ("YYYY-MM-DD", the client's local day), without timezone shifts. */
export function shortDate(date: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(date)
  return m ? `${m[2]}/${m[3]}` : date
}

/** A 0..1 share as a percentage string, e.g. 0.4234 → "42.3%". */
export function formatPercent(rate: number | null | undefined, locale = 'en'): string {
  const n = Number(rate)
  if (!Number.isFinite(n)) return '—'
  return new Intl.NumberFormat(locale, { style: 'percent', maximumFractionDigits: 1 }).format(Math.min(Math.max(n, 0), 1))
}

/** Bar widths (percent of the widest) for a ranked distribution. */
export function shareWidths(values: number[]): number[] {
  const max = Math.max(0, ...values)
  return values.map(v => (max > 0 && v > 0 ? Math.max(2, Math.round((v / max) * 1000) / 10) : 0))
}

/** The client's UTC offset in minutes east of UTC, as the stats endpoints expect. */
export function utcOffsetMinutes(date = new Date()): number {
  return -date.getTimezoneOffset()
}
