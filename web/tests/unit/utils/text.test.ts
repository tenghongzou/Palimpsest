import { describe, expect, it } from 'vitest'
import { splitParagraphs } from '~/utils/text'
import { newUuid } from '~/utils/uuid'

describe('splitParagraphs', () => {
  it('drops blank lines and trims', () => {
    expect(splitParagraphs('  第一段\n\n\r\n 第二段 \r\n第三段')).toEqual(['第一段', '第二段', '第三段'])
  })

  it('handles empty content', () => {
    expect(splitParagraphs('')).toEqual([])
    expect(splitParagraphs(null)).toEqual([])
  })

  it('keeps markup as text (the reader never renders HTML)', () => {
    expect(splitParagraphs('<img src=x onerror=alert(1)>')).toEqual(['<img src=x onerror=alert(1)>'])
  })
})

describe('newUuid', () => {
  const V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/

  it('returns distinct v4 UUIDs', () => {
    const ids = new Set(Array.from({ length: 50 }, newUuid))
    expect(ids.size).toBe(50)
    for (const id of ids) expect(id).toMatch(V4)
  })

  it('works without crypto.randomUUID', () => {
    const original = globalThis.crypto
    Object.defineProperty(globalThis, 'crypto', {
      value: { getRandomValues: original.getRandomValues.bind(original) },
      configurable: true,
    })
    try {
      expect(newUuid()).toMatch(V4)
    }
    finally {
      Object.defineProperty(globalThis, 'crypto', { value: original, configurable: true })
    }
  })
})
