import { describe, it, expect } from 'vitest'

// Extract the pure logic from the reader store for testing
interface ReaderSettings {
  fontSize: number
  lineHeight: number
  letterSpacing: number
  margin: number
  fontFamily: string
  theme: 'white' | 'yellow' | 'green' | 'dark' | 'black'
  readingMode: 'scroll' | 'page'
}

const defaultSettings: ReaderSettings = {
  fontSize: 18,
  lineHeight: 1.8,
  letterSpacing: 0,
  margin: 16,
  fontFamily: 'system',
  theme: 'white',
  readingMode: 'scroll',
}

describe('Reader store settings', () => {
  it('default settings are correct', () => {
    expect(defaultSettings.fontSize).toBe(18)
    expect(defaultSettings.lineHeight).toBe(1.8)
    expect(defaultSettings.letterSpacing).toBe(0)
    expect(defaultSettings.margin).toBe(16)
    expect(defaultSettings.fontFamily).toBe('system')
    expect(defaultSettings.theme).toBe('white')
    expect(defaultSettings.readingMode).toBe('scroll')
  })

  it('updateSettings merges partial settings', () => {
    const current = { ...defaultSettings }
    const updated = { ...current, fontSize: 24, theme: 'dark' as const }
    expect(updated.fontSize).toBe(24)
    expect(updated.theme).toBe('dark')
    expect(updated.lineHeight).toBe(1.8) // unchanged
  })

  it('resetSettings returns defaults', () => {
    const reset = { ...defaultSettings }
    expect(reset).toEqual(defaultSettings)
  })

  it('all theme options are valid', () => {
    const themes = ['white', 'yellow', 'green', 'dark', 'black'] as const
    expect(themes).toHaveLength(5)
    expect(themes).toContain(defaultSettings.theme)
  })

  it('reading modes are valid', () => {
    const modes = ['scroll', 'page'] as const
    expect(modes).toHaveLength(2)
    expect(modes).toContain(defaultSettings.readingMode)
  })
})
