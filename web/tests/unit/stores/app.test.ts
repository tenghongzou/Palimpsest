import { describe, it, expect } from 'vitest'
import { DEFAULT_LOCALE, LOCALE_NAMES, SUPPORTED_LOCALES, intlLocale, isSupportedLocale } from '~/i18n/constants'

describe('UI locales', () => {
  it('supports the account language_pref values, zh-TW by default', () => {
    expect([...SUPPORTED_LOCALES]).toEqual(['zh-TW', 'zh-CN', 'en'])
    expect(DEFAULT_LOCALE).toBe('zh-TW')
    expect(Object.keys(LOCALE_NAMES).sort()).toEqual([...SUPPORTED_LOCALES].sort())
  })

  it('validates locale codes', () => {
    expect(isSupportedLocale('zh-CN')).toBe(true)
    expect(isSupportedLocale('zh-HK')).toBe(false)
    expect(isSupportedLocale(undefined)).toBe(false)
  })

  it('maps codes to Intl locales', () => {
    expect(intlLocale('en')).toBe('en-US')
    expect(intlLocale('zh-TW')).toBe('zh-TW')
  })
})
