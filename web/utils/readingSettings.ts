// Reader preferences: the local (camelCase) shape used by the reader store and
// conversion to and from the server's ReadingSettings.
import type { ApiReadingSettings } from '~/types/models'

export type ReaderTheme = 'white' | 'sepia' | 'green' | 'dark' | 'black'
export type ReadingMode = 'scroll' | 'page'
/** How page mode turns pages (labels: i18n keys `reader.settings.animations.<value>`). */
export type PageAnimation = 'none' | 'slide' | 'cover' | 'curl'
export const PAGE_ANIMATIONS: readonly PageAnimation[] = ['none', 'slide', 'cover', 'curl']

export interface ReaderSettings {
  fontSize: number
  lineHeight: number
  letterSpacing: number
  margin: number
  fontFamily: string
  theme: ReaderTheme
  readingMode: ReadingMode
  pageAnimation: PageAnimation
  brightness: number
  keepScreenOn: boolean
  autoChapter: boolean
}

export const DEFAULT_READER_SETTINGS: Readonly<ReaderSettings> = Object.freeze({
  fontSize: 18,
  lineHeight: 1.8,
  letterSpacing: 0,
  margin: 16,
  fontFamily: 'system',
  theme: 'white',
  readingMode: 'scroll',
  pageAnimation: 'slide',
  brightness: 100,
  keepScreenOn: true,
  autoChapter: true,
})

export const SETTING_LIMITS = {
  fontSize: { min: 12, max: 36, step: 1 },
  lineHeight: { min: 1.2, max: 3, step: 0.1 },
  letterSpacing: { min: 0, max: 5, step: 0.5 },
  margin: { min: 0, max: 64, step: 4 },
  brightness: { min: 10, max: 100, step: 5 },
} as const

// Labels: i18n keys `reader.settings.themes.<key>` and `reader.settings.fonts.<key>`.
export const READER_THEMES: Record<ReaderTheme, { bg: string, text: string }> = {
  white: { bg: '#ffffff', text: '#333333' },
  sepia: { bg: '#f5f0e0', text: '#4a4a4a' },
  green: { bg: '#e0f0e0', text: '#3a4a3a' },
  dark: { bg: '#2c2c2c', text: '#c0c0c0' },
  black: { bg: '#000000', text: '#808080' },
}

// CSS font stacks (font names are not UI copy).
export const FONT_FAMILIES: Record<string, { css: string }> = {
  system: { css: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif' },
  song: { css: '"SimSun", "宋体", "Noto Serif TC", serif' },
  kai: { css: '"KaiTi", "楷体", "DFKai-SB", serif' },
  serif: { css: '"Noto Serif TC", "Noto Serif SC", serif' },
}

function clamp(value: unknown, min: number, max: number, fallback: number, decimals = 0): number {
  const n = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(n)) return fallback
  const factor = 10 ** decimals
  return Math.min(max, Math.max(min, Math.round(n * factor) / factor))
}

/**
 * Coerces any stored or partial settings into valid ones. Older clients saved
 * the sepia theme as "yellow".
 */
export function normalizeSettings(input: Partial<Record<keyof ReaderSettings, unknown>> | null | undefined): ReaderSettings {
  const s = input ?? {}
  const d = DEFAULT_READER_SETTINGS
  const L = SETTING_LIMITS
  const rawTheme = s.theme === 'yellow' ? 'sepia' : s.theme
  const fontFamily = typeof s.fontFamily === 'string' && s.fontFamily.trim() ? s.fontFamily.slice(0, 50) : d.fontFamily
  return {
    fontSize: clamp(s.fontSize, L.fontSize.min, L.fontSize.max, d.fontSize),
    lineHeight: clamp(s.lineHeight, L.lineHeight.min, L.lineHeight.max, d.lineHeight, 2),
    letterSpacing: clamp(s.letterSpacing, L.letterSpacing.min, L.letterSpacing.max, d.letterSpacing, 2),
    margin: clamp(s.margin, L.margin.min, L.margin.max, d.margin),
    fontFamily,
    theme: typeof rawTheme === 'string' && rawTheme in READER_THEMES ? rawTheme as ReaderTheme : d.theme,
    readingMode: s.readingMode === 'page' ? 'page' : 'scroll',
    pageAnimation: PAGE_ANIMATIONS.includes(s.pageAnimation as PageAnimation) ? s.pageAnimation as PageAnimation : d.pageAnimation,
    brightness: clamp(s.brightness, L.brightness.min, L.brightness.max, d.brightness),
    keepScreenOn: typeof s.keepScreenOn === 'boolean' ? s.keepScreenOn : d.keepScreenOn,
    autoChapter: typeof s.autoChapter === 'boolean' ? s.autoChapter : d.autoChapter,
  }
}

/** The full replacement body for PUT /users/me/reading-settings. */
export function toServerSettings(settings: ReaderSettings): ApiReadingSettings {
  const s = normalizeSettings(settings)
  return {
    font_size: s.fontSize,
    line_height: s.lineHeight,
    letter_spacing: s.letterSpacing,
    margin: s.margin,
    font_family: s.fontFamily,
    theme: s.theme,
    reading_mode: s.readingMode,
    page_animation: s.pageAnimation,
    brightness: s.brightness,
    keep_screen_on: s.keepScreenOn,
    auto_chapter: s.autoChapter,
  }
}

export function fromServerSettings(server: ApiReadingSettings): ReaderSettings {
  return normalizeSettings({
    fontSize: server.font_size,
    lineHeight: server.line_height,
    letterSpacing: server.letter_spacing,
    margin: server.margin,
    fontFamily: server.font_family,
    theme: server.theme,
    readingMode: server.reading_mode,
    pageAnimation: server.page_animation,
    brightness: server.brightness,
    keepScreenOn: server.keep_screen_on,
    autoChapter: server.auto_chapter,
  })
}

/** The server reports a zero `updated_at` for users who never saved settings. */
export function serverSettingsSaved(server: ApiReadingSettings): boolean {
  if (!server.updated_at) return false
  const t = new Date(server.updated_at).getTime()
  return Number.isFinite(t) && new Date(t).getUTCFullYear() > 1970
}

export function sameSettings(a: ReaderSettings, b: ReaderSettings): boolean {
  return (Object.keys(DEFAULT_READER_SETTINGS) as (keyof ReaderSettings)[]).every(k => a[k] === b[k])
}
