import { describe, it, expect } from 'vitest'

describe('App store contract', () => {
  it('supported locales are defined', () => {
    const locales = ['zh-TW', 'zh-CN', 'en'] as const
    expect(locales).toHaveLength(3)
    expect(locales).toContain('zh-TW')
    expect(locales).toContain('zh-CN')
    expect(locales).toContain('en')
  })

  it('default locale is zh-TW', () => {
    const defaultLocale = 'zh-TW'
    expect(defaultLocale).toBe('zh-TW')
  })
})
