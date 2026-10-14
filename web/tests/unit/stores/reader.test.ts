import { describe, it, expect } from 'vitest'
import {
  DEFAULT_READER_SETTINGS,
  fromServerSettings,
  normalizeSettings,
  sameSettings,
  serverSettingsSaved,
  toServerSettings,
} from '~/utils/readingSettings'

describe('reader settings', () => {
  it('defaults match the server defaults', () => {
    expect(toServerSettings({ ...DEFAULT_READER_SETTINGS })).toEqual({
      font_size: 18,
      line_height: 1.8,
      letter_spacing: 0,
      margin: 16,
      font_family: 'system',
      theme: 'white',
      reading_mode: 'scroll',
      brightness: 100,
      keep_screen_on: true,
      auto_chapter: true,
    })
  })

  it('fills missing fields from defaults (settings saved by older versions)', () => {
    const s = normalizeSettings({ fontSize: 24, theme: 'dark' })
    expect(s.fontSize).toBe(24)
    expect(s.theme).toBe('dark')
    expect(s.brightness).toBe(100)
    expect(s.autoChapter).toBe(true)
  })

  it('maps the old "yellow" theme to sepia and rejects unknown themes', () => {
    expect(normalizeSettings({ theme: 'yellow' }).theme).toBe('sepia')
    expect(normalizeSettings({ theme: 'purple' }).theme).toBe('white')
  })

  it('clamps values into the ranges the API accepts', () => {
    const s = normalizeSettings({ fontSize: 99, lineHeight: 0.5, letterSpacing: 9, margin: -3, brightness: 2 })
    expect(s).toMatchObject({ fontSize: 36, lineHeight: 1.2, letterSpacing: 5, margin: 0, brightness: 10 })
    expect(normalizeSettings({ fontSize: 'x' as unknown as number }).fontSize).toBe(18)
    expect(normalizeSettings({ fontSize: 17.6 }).fontSize).toBe(18)
  })

  it('round-trips through the server shape', () => {
    const local = normalizeSettings({ fontSize: 22, lineHeight: 2.2, theme: 'sepia', readingMode: 'page', keepScreenOn: false })
    expect(fromServerSettings(toServerSettings(local))).toEqual(local)
    expect(sameSettings(local, fromServerSettings(toServerSettings(local)))).toBe(true)
    expect(sameSettings(local, { ...local, fontSize: 23 })).toBe(false)
  })

  it('detects settings the user never saved', () => {
    const base = toServerSettings({ ...DEFAULT_READER_SETTINGS })
    expect(serverSettingsSaved({ ...base, updated_at: '0001-01-01T00:00:00Z' })).toBe(false)
    expect(serverSettingsSaved(base)).toBe(false)
    expect(serverSettingsSaved({ ...base, updated_at: '2026-10-14T01:00:00+08:00' })).toBe(true)
  })
})
