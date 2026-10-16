import { describe, expect, it } from 'vitest'
import {
  MODERATION_FLAG_CODES, flagLabel, flagText, isAiFlag, itemKey, pageAfterRemoval, riskLevel, riskPercent, riskStatus,
  validateTerm, withoutItems,
} from '~/utils/moderation'
import { SUPPORTED_LOCALES } from '~/i18n/constants'
import { makeT } from '../i18n'

const t = makeT('zh-TW')

describe('flag labels', () => {
  it.each(SUPPORTED_LOCALES)('labels every documented flag code in %s', (locale) => {
    const tl = makeT(locale)
    for (const code of MODERATION_FLAG_CODES) {
      const label = flagLabel(tl, code)
      expect(label, code).not.toBe(code)
      expect(label, code).not.toContain('admin.')
    }
  })

  it('shows unknown codes as is', () => {
    expect(flagLabel(t, 'ai_new_category')).toBe('ai_new_category')
  })

  it('adds the detail, such as the matched term', () => {
    expect(flagText(t, { code: 'blocked_term', detail: '廣告' })).toBe('送審詞：廣告')
    expect(flagText(makeT('en'), { code: 'link', detail: 'example.com' })).toBe('Link: example.com')
    expect(flagText(t, { code: 'shouting' })).toBe('大量大寫或驚嘆號')
    expect(flagText(t, { code: 'repetition', detail: '  ' })).toBe('重複內容')
  })

  it('tells AI flags from rule flags', () => {
    expect(isAiFlag('ai_spam')).toBe(true)
    expect(isAiFlag('link')).toBe(false)
  })
})

describe('risk', () => {
  it('buckets and formats scores', () => {
    expect(riskLevel(0.1)).toBe('low')
    expect(riskLevel(0.4)).toBe('medium')
    expect(riskLevel(0.69)).toBe('medium')
    expect(riskLevel(0.7)).toBe('high')
    expect(riskLevel(undefined)).toBe('low')
    expect(riskPercent(0.456)).toBe(46)
    expect(riskPercent(1.4)).toBe(100)
    expect(riskPercent(-1)).toBe(0)
    expect(riskPercent(Number.NaN)).toBe(0)
    expect(riskStatus('high')).toBe('error')
    expect(riskStatus('medium')).toBe('warning')
    expect(riskStatus('low')).toBe('success')
  })
})

describe('terms', () => {
  it('requires 1 to 50 characters after trimming', () => {
    expect(validateTerm('')).toBe('required')
    expect(validateTerm('   ')).toBe('required')
    expect(validateTerm(null)).toBe('required')
    expect(validateTerm('廣告')).toBeNull()
    expect(validateTerm('字'.repeat(50))).toBeNull()
    expect(validateTerm('字'.repeat(51))).toBe('tooLong')
    // Characters outside the BMP count once.
    expect(validateTerm('😀'.repeat(50))).toBeNull()
  })
})

describe('queue items', () => {
  const items = [
    { type: 'review', id: 'a' },
    { type: 'comment', id: 'a' },
    { type: 'comment', id: 'b' },
  ]

  it('keys items by type and id', () => {
    expect(itemKey(items[0]!)).toBe('review:a')
  })

  it('removes items by key without touching the other type', () => {
    expect(withoutItems(items, ['comment:a'])).toEqual([{ type: 'review', id: 'a' }, { type: 'comment', id: 'b' }])
    expect(withoutItems(items, [])).toEqual(items)
    expect(withoutItems(items, ['review:a', 'comment:b'])).toEqual([{ type: 'comment', id: 'a' }])
  })

  it('reloads the same page unless it no longer exists', () => {
    expect(pageAfterRemoval(1, 20, 5)).toBe(1)
    expect(pageAfterRemoval(3, 20, 41)).toBe(3)
    expect(pageAfterRemoval(3, 20, 40)).toBe(2)
    expect(pageAfterRemoval(2, 20, 0)).toBe(1)
  })
})
