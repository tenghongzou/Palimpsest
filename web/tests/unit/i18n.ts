// A small stand-in for vue-i18n's `t` over the real locale files, for unit
// tests of pure helpers that take a translator. Supports named interpolation
// ({name}), literal interpolation ({'@'}) and pipe-separated plural forms.
import zhTW from '~/i18n/locales/zh-TW.json'
import zhCN from '~/i18n/locales/zh-CN.json'
import en from '~/i18n/locales/en.json'
import type { FormatContext, Translate } from '~/utils/format'

export const LOCALE_MESSAGES = { 'zh-TW': zhTW, 'zh-CN': zhCN, 'en': en } as Record<string, unknown>

function lookup(messages: unknown, key: string): unknown {
  return key.split('.').reduce<unknown>((node, part) => (node && typeof node === 'object' ? (node as Record<string, unknown>)[part] : undefined), messages)
}

function pickPlural(message: string, n: number | undefined): string {
  const forms = message.split(/\s*\|\s*/)
  if (forms.length === 1 || n === undefined) return forms[0]!
  if (forms.length === 2) return n === 1 ? forms[0]! : forms[1]!
  return forms[Math.min(n, 2)]!
}

export function makeT(locale = 'zh-TW'): Translate {
  const messages = LOCALE_MESSAGES[locale]
  return (key, named = {}, plural) => {
    const raw = lookup(messages, key)
    if (typeof raw !== 'string') return key
    const n = plural ?? (typeof named.n === 'number' ? named.n : undefined)
    return pickPlural(raw, plural ?? (raw.includes('|') ? n : undefined))
      .replace(/\{'([^']*)'\}/g, (_, literal: string) => literal)
      .replace(/\{(\w+)\}/g, (_, name: string) => (name in named ? String(named[name]) : `{${name}}`))
  }
}

export function formatContext(locale = 'zh-TW'): FormatContext {
  return { t: makeT(locale), locale }
}
