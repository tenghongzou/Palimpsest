import { describe, expect, it } from 'vitest'
import {
  paragraphCountMap,
  paragraphExcerpt,
  paragraphsAligned,
  threadPanel,
  totalParagraphComments,
} from '~/utils/paragraphComments'
import { splitParagraphs } from '~/utils/text'

describe('paragraph indexing', () => {
  // The rule bookmarks, progress and paragraph comments share with the Flutter
  // app: split on newlines, trim, drop blank lines.
  it('skips blank lines so indexes match the Flutter reader', () => {
    const content = '第一段。\n\n  第二段。  \r\n\r\n\n第三段。\n'
    expect(splitParagraphs(content)).toEqual(['第一段。', '第二段。', '第三段。'])
  })

  it('treats whitespace-only lines (including full-width spaces) as blank', () => {
    expect(splitParagraphs('甲\n　　\n乙')).toEqual(['甲', '乙'])
  })
})

describe('paragraphCountMap', () => {
  it('maps paragraph indexes to counts', () => {
    expect(paragraphCountMap([{ paragraph_index: 0, count: 2 }, { paragraph_index: 4, count: 1 }]))
      .toEqual({ 0: 2, 4: 1 })
  })

  it('drops entries outside the chapter or without comments', () => {
    const list = [
      { paragraph_index: 1, count: 3 },
      { paragraph_index: 9, count: 1 },
      { paragraph_index: -1, count: 1 },
      { paragraph_index: 2, count: 0 },
      { paragraph_index: 1.5, count: 1 },
    ]
    expect(paragraphCountMap(list, 5)).toEqual({ 1: 3 })
  })

  it('sums duplicates and handles empty input', () => {
    expect(paragraphCountMap([{ paragraph_index: 3, count: 1 }, { paragraph_index: 3, count: 2 }])).toEqual({ 3: 3 })
    expect(paragraphCountMap([])).toEqual({})
    expect(paragraphCountMap(null)).toEqual({})
  })

  it('totals counts', () => {
    expect(totalParagraphComments({ 0: 2, 3: 5 })).toBe(7)
    expect(totalParagraphComments({})).toBe(0)
  })
})

describe('paragraphsAligned', () => {
  const original = '一\n\n二\n\n三'

  it('is aligned without a translation', () => {
    expect(paragraphsAligned(original, null)).toBe(true)
    expect(paragraphsAligned(original, original)).toBe(true)
  })

  it('compares paragraph counts of a translation', () => {
    expect(paragraphsAligned(original, 'one\ntwo\nthree')).toBe(true)
    expect(paragraphsAligned(original, 'one two\nthree')).toBe(false)
  })
})

describe('threadPanel (opening a thread from a notification)', () => {
  it('opens the paragraph panel for paragraph comments', () => {
    expect(threadPanel({ paragraph_index: 2 }, 5)).toEqual({ kind: 'paragraph', index: 2 })
    expect(threadPanel({ paragraph_index: 0 }, 1)).toEqual({ kind: 'paragraph', index: 0 })
  })

  it('opens the chapter comments for whole-chapter threads', () => {
    expect(threadPanel({}, 5)).toEqual({ kind: 'chapter' })
    expect(threadPanel({ paragraph_index: null }, 5)).toEqual({ kind: 'chapter' })
    expect(threadPanel(null, 5)).toEqual({ kind: 'chapter' })
  })

  it('falls back to the chapter comments when the paragraph is not shown', () => {
    expect(threadPanel({ paragraph_index: 5 }, 5)).toEqual({ kind: 'chapter' })
    expect(threadPanel({ paragraph_index: 1 }, 5, false)).toEqual({ kind: 'chapter' })
  })
})

describe('paragraphExcerpt', () => {
  it('shortens long paragraphs', () => {
    expect(paragraphExcerpt('  短句  ')).toBe('短句')
    expect(paragraphExcerpt('字'.repeat(90), 80)).toBe(`${'字'.repeat(80)}…`)
    expect(paragraphExcerpt(undefined)).toBe('')
  })
})
