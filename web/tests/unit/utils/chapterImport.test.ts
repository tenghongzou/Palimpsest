import { describe, expect, it } from 'vitest'
import { MAX_IMPORT_CHAPTERS, matchHeading, parseChapterImport, parseChapterNumeral } from '~/utils/chapterImport'
import { makeT } from '../i18n'

describe('parseChapterNumeral', () => {
  it.each([
    ['1', 1],
    ['０１２', 12],
    ['一', 1],
    ['十', 10],
    ['十二', 12],
    ['二十', 20],
    ['二十三', 23],
    ['一百', 100],
    ['一百零五', 105],
    ['兩千三百四十五', 2345],
    ['一萬零一', 10001],
    ['〇', 0],
  ])('%s -> %d', (raw, expected) => {
    expect(parseChapterNumeral(raw)).toBe(expected)
  })

  it('rejects other text', () => {
    expect(parseChapterNumeral('abc')).toBeNaN()
    expect(parseChapterNumeral('')).toBeNaN()
  })
})

describe('matchHeading', () => {
  it('recognises common heading styles', () => {
    expect(matchHeading('第一章 垫桌脚的书')).toBe(1)
    expect(matchHeading('  第 12 章：標題')).toBe(12)
    expect(matchHeading('第三十回')).toBe(30)
    expect(matchHeading('Chapter 7: The End')).toBe(7)
    expect(matchHeading('chapter 8')).toBe(8)
  })

  it('ignores ordinary lines', () => {
    expect(matchHeading('他說第一章很好看')).toBeNull()
    expect(matchHeading('Chapters are fun')).toBeNull()
    expect(matchHeading('')).toBeNull()
  })
})

describe('parseChapterImport (text)', () => {
  it('splits by headings and keeps paragraph breaks', () => {
    const text = '序言會被忽略\n\n第一章 開始\n第一段\n\n第二段\n\r\n第二章 繼續\r\n內容二\n'
    const { chapters, errors } = parseChapterImport(text, { is_published: true, is_free: true })
    expect(errors).toEqual([])
    expect(chapters).toEqual([
      { title: '第一章 開始', content: '第一段\n\n第二段', chapter_number: 1, is_published: true, is_free: true },
      { title: '第二章 繼續', content: '內容二', chapter_number: 2, is_published: true, is_free: true },
    ])
  })

  it('reports chapters without content and duplicate numbers', () => {
    const { chapters, errors } = parseChapterImport('第1章 a\n\n第1章 b\n文字')
    expect(chapters).toHaveLength(2)
    expect(errors.some(e => e.key === 'admin.import.errors.noContent' && e.params?.title === '第1章 a')).toBe(true)
    expect(errors).toContainEqual({ key: 'admin.import.errors.duplicateNumber', params: { n: 1 } })
  })

  it('reports text without headings', () => {
    const { chapters, errors } = parseChapterImport('只是一段文字')
    expect(chapters).toHaveLength(0)
    expect(errors).toHaveLength(1)
  })

  it('reports empty input', () => {
    expect(parseChapterImport('   ').errors).toEqual([{ key: 'admin.import.errors.empty' }])
  })

  it('limits the number of chapters', () => {
    const text = Array.from({ length: MAX_IMPORT_CHAPTERS + 1 }, (_, i) => `第${i + 1}章\n內容`).join('\n')
    const { chapters, errors } = parseChapterImport(text)
    expect(chapters).toHaveLength(MAX_IMPORT_CHAPTERS + 1)
    expect(errors.some(e => e.key === 'admin.import.errors.tooMany' && e.params?.max === MAX_IMPORT_CHAPTERS)).toBe(true)
  })
})

describe('parseChapterImport (JSON)', () => {
  it('numbers chapters from startNumber when chapter_number is missing', () => {
    const json = JSON.stringify([
      { title: 'A', content: 'a' },
      { title: 'B', content: 'b', chapter_number: 10, is_published: false },
      { title: 'C', content: 'c' },
    ])
    const { chapters, errors } = parseChapterImport(json, { startNumber: 4, is_published: true })
    expect(errors).toEqual([])
    expect(chapters.map(c => c.chapter_number)).toEqual([4, 10, 11])
    expect(chapters.map(c => c.is_published)).toEqual([true, false, true])
  })

  it('reports invalid JSON and missing fields', () => {
    expect(parseChapterImport('[oops').errors).toEqual([{ key: 'admin.import.errors.invalidJson' }])
    const { errors } = parseChapterImport('[{"title":"","content":"x"}]')
    expect(errors).toEqual([{ key: 'admin.import.errors.missingTitle', params: { n: 1 } }])
  })
})

describe('import problems are translatable', () => {
  it('maps to messages in the UI language', () => {
    const t = makeT('en')
    const { errors } = parseChapterImport('第1章 a\n\n第1章 b\n文字')
    const texts = errors.map(e => t(e.key, e.params))
    expect(texts).toContain('"第1章 a" has no content')
    expect(texts).toContain('Duplicate chapter number: 1')
    expect(makeT('zh-TW')('admin.import.errors.missingTitle', { n: 2 })).toBe('第 2 筆缺少 title')
  })
})
