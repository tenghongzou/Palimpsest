import { describe, expect, it } from 'vitest'
import { SUPPORTED_LOCALES } from '~/i18n/constants'
import { LOCALE_MESSAGES } from '../i18n'

type Messages = { [key: string]: string | Messages }

function flatten(messages: Messages, prefix = ''): Record<string, string> {
  const out: Record<string, string> = {}
  for (const [key, value] of Object.entries(messages)) {
    const path = prefix ? `${prefix}.${key}` : key
    if (typeof value === 'string') out[path] = value
    else Object.assign(out, flatten(value, path))
  }
  return out
}

const flat = Object.fromEntries(SUPPORTED_LOCALES.map(l => [l, flatten(LOCALE_MESSAGES[l] as Messages)])) as Record<string, Record<string, string>>
const reference = flat['zh-TW']!

/** Named placeholders such as {n} (not literal interpolations like {'@'}). */
function placeholders(message: string): string[] {
  return [...new Set([...message.matchAll(/\{(\w+)\}/g)].map(m => m[1]!))].sort()
}

describe('locale files', () => {
  it('has a file for every supported locale', () => {
    for (const locale of SUPPORTED_LOCALES) expect(Object.keys(flat[locale]!).length).toBeGreaterThan(100)
  })

  it.each(SUPPORTED_LOCALES.filter(l => l !== 'zh-TW'))('%s has exactly the zh-TW key set', (locale) => {
    const keys = Object.keys(flat[locale]!)
    const missing = Object.keys(reference).filter(k => !(k in flat[locale]!))
    const extra = keys.filter(k => !(k in reference))
    expect({ missing, extra }).toEqual({ missing: [], extra: [] })
  })

  it.each(SUPPORTED_LOCALES)('%s has no empty values', (locale) => {
    const empty = Object.entries(flat[locale]!).filter(([, v]) => !v.trim()).map(([k]) => k)
    expect(empty).toEqual([])
  })

  it.each(SUPPORTED_LOCALES)('%s uses the same placeholders as zh-TW', (locale) => {
    const mismatched = Object.entries(flat[locale]!)
      .filter(([k, v]) => reference[k] !== undefined && placeholders(v).join() !== placeholders(reference[k]!).join())
      .map(([k]) => k)
    expect(mismatched).toEqual([])
  })

  it.each(SUPPORTED_LOCALES)('%s has no characters vue-i18n would treat as syntax', (locale) => {
    // "@" starts a linked message and "$" / "%" are reserved; write {'@'} for a literal.
    const bad = Object.entries(flat[locale]!).filter(([, v]) => /[@$%]/.test(v.replace(/\{'[^']*'\}/g, ''))).map(([k]) => k)
    expect(bad).toEqual([])
  })

  it('only uses plural forms ("a | b") in English', () => {
    for (const locale of ['zh-TW', 'zh-CN']) {
      expect(Object.entries(flat[locale]!).filter(([, v]) => v.includes('|')).map(([k]) => k)).toEqual([])
    }
  })

  it('writes zh-CN in Simplified Chinese with mainland wording', () => {
    const text = Object.values(flat['zh-CN']!).join('\n')
    // Traditional-only characters and Taiwan wording that must not appear.
    for (const term of ['帳', '號', '設定', '儲存', '載入', '離線', '檢舉', '登入', '書', '網路', '暱稱']) {
      expect(text, term).not.toContain(term)
    }
    expect(flat['zh-CN']!['common.login']).toBe('登录')
    expect(flat['zh-CN']!['header.user.settings']).toBe('账号设置')
  })
})
