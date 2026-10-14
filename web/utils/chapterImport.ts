// Parses chapters pasted into the admin batch import: either plain text split
// by chapter headings ("第一章 標題", "第12回", "Chapter 3: Title") or a JSON
// array of chapter objects.

export const MAX_IMPORT_CHAPTERS = 500

export interface ImportedChapter {
  title: string
  content: string
  chapter_number: number
  is_published?: boolean
  is_free?: boolean
}

export interface ChapterImportOptions {
  /** Number given to the first chapter when the input has no numbers (JSON without chapter_number). */
  startNumber?: number
  is_published?: boolean
  is_free?: boolean
}

/** A problem found in the input, as an i18n key (`admin.import.errors.*`) with its parameters. */
export interface ImportProblem {
  key: string
  params?: Record<string, string | number>
}

export interface ChapterImportResult {
  chapters: ImportedChapter[]
  errors: ImportProblem[]
}

const problem = (name: string, params?: ImportProblem['params']): ImportProblem =>
  ({ key: `admin.import.errors.${name}`, ...(params ? { params } : {}) })

const DIGITS: Record<string, number> = {
  零: 0, 〇: 0, 一: 1, 二: 2, 兩: 2, 两: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9,
}
const UNITS: Record<string, number> = { 十: 10, 百: 100, 千: 1000 }

/** Converts Arabic (half or full width) or Chinese numerals to a number; NaN if invalid. */
export function parseChapterNumeral(raw: string): number {
  const text = raw.trim().replace(/[０-９]/g, d => String.fromCharCode(d.charCodeAt(0) - 0xFEE0))
  if (/^\d+$/.test(text)) return Number(text)
  if (!text || !/^[零〇一二兩两三四五六七八九十百千萬万]+$/.test(text)) return Number.NaN

  let total = 0
  let section = 0
  let digit = -1
  for (const ch of text) {
    if (ch in DIGITS) {
      digit = DIGITS[ch]
    }
    else if (ch in UNITS) {
      section += (digit < 0 ? 1 : digit) * UNITS[ch]
      digit = -1
    }
    else {
      // 萬 / 万
      total += (section + Math.max(digit, 0) || 1) * 10000
      section = 0
      digit = -1
    }
  }
  return total + section + Math.max(digit, 0)
}

const HEADING = /^\s*(?:第\s*([0-9０-９零〇一二兩两三四五六七八九十百千萬万]+)\s*[章回節节話话卷]|chapter\s+(\d+)\b)\s*[:：.、\-—]?\s*(.*)$/i

/** Returns the chapter number if `line` is a chapter heading. */
export function matchHeading(line: string): number | null {
  const m = HEADING.exec(line)
  if (!m) return null
  const n = parseChapterNumeral(m[1] ?? m[2] ?? '')
  return Number.isFinite(n) ? n : null
}

function trimBlankLines(lines: string[]): string {
  return lines.join('\n').replace(/^\s*\n/, '').trim()
}

function parseText(text: string, opts: ChapterImportOptions): ChapterImportResult {
  const chapters: ImportedChapter[] = []
  const errors: ImportProblem[] = []
  let current: { title: string, number: number, lines: string[] } | null = null

  const flush = () => {
    if (!current) return
    const content = trimBlankLines(current.lines)
    if (!content) errors.push(problem('noContent', { title: current.title }))
    chapters.push({
      title: current.title.slice(0, 200),
      content,
      chapter_number: current.number,
      is_published: opts.is_published,
      is_free: opts.is_free,
    })
  }

  for (const line of text.replace(/\r\n?/g, '\n').split('\n')) {
    const number = matchHeading(line)
    if (number !== null) {
      flush()
      current = { title: line.trim(), number, lines: [] }
    }
    else if (current) {
      current.lines.push(line)
    }
  }
  flush()

  if (chapters.length === 0) errors.push(problem('noHeadings'))
  return { chapters, errors }
}

function parseJson(text: string, opts: ChapterImportOptions): ChapterImportResult {
  const errors: ImportProblem[] = []
  let data: unknown
  try {
    data = JSON.parse(text)
  }
  catch {
    return { chapters: [], errors: [problem('invalidJson')] }
  }
  if (!Array.isArray(data)) return { chapters: [], errors: [problem('notArray')] }

  let next = opts.startNumber ?? 1
  const chapters: ImportedChapter[] = []
  data.forEach((item, i) => {
    const row = (item ?? {}) as Record<string, unknown>
    const title = typeof row.title === 'string' ? row.title.trim() : ''
    const content = typeof row.content === 'string' ? row.content.trim() : ''
    const number = typeof row.chapter_number === 'number' && Number.isInteger(row.chapter_number)
      ? row.chapter_number
      : next
    next = number + 1
    if (!title) errors.push(problem('missingTitle', { n: i + 1 }))
    if (!content) errors.push(problem('missingContent', { n: i + 1 }))
    chapters.push({
      title: title.slice(0, 200),
      content,
      chapter_number: number,
      is_published: typeof row.is_published === 'boolean' ? row.is_published : opts.is_published,
      is_free: typeof row.is_free === 'boolean' ? row.is_free : opts.is_free,
    })
  })
  if (chapters.length === 0) errors.push(problem('noChapters'))
  return { chapters, errors }
}

/** Parses pasted text or JSON into chapters and lists any problems found. */
export function parseChapterImport(input: string, opts: ChapterImportOptions = {}): ChapterImportResult {
  const text = input.trim()
  if (!text) return { chapters: [], errors: [problem('empty')] }

  const result = text.startsWith('[') ? parseJson(text, opts) : parseText(text, opts)

  const seen = new Set<number>()
  for (const ch of result.chapters) {
    if (ch.chapter_number < 1) result.errors.push(problem('invalidNumber', { title: ch.title }))
    if (seen.has(ch.chapter_number)) result.errors.push(problem('duplicateNumber', { n: ch.chapter_number }))
    seen.add(ch.chapter_number)
  }
  if (result.chapters.length > MAX_IMPORT_CHAPTERS) {
    result.errors.push(problem('tooMany', { max: MAX_IMPORT_CHAPTERS, count: result.chapters.length }))
  }
  return result
}
