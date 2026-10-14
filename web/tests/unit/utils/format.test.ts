import { describe, expect, it } from 'vitest'
import {
  chapterLabel, formatDateTime, formatDuration, formatRelativeTime, formatViewCount, formatWordCount, novelStatus,
} from '~/utils/format'
import { formatContext } from '../i18n'

const zhTW = formatContext('zh-TW')
const zhCN = formatContext('zh-CN')
const en = formatContext('en')

describe('chapterLabel', () => {
  it('adds the number only when the title lacks one', () => {
    expect(chapterLabel(3, '沒有旗的船', zhTW)).toBe('第3章 沒有旗的船')
    expect(chapterLabel(3, '第三章 沒有旗的船', zhTW)).toBe('第三章 沒有旗的船')
    expect(chapterLabel(12, '第12章 歸來', zhTW)).toBe('第12章 歸來')
    expect(chapterLabel(1, '第一回 起', zhTW)).toBe('第一回 起')
    expect(chapterLabel(5, '', zhTW)).toBe('第5章')
    expect(chapterLabel(2, '第一次見面', zhTW)).toBe('第2章 第一次見面')
  })

  it('follows the UI language for the added number', () => {
    expect(chapterLabel(3, '沒有旗的船', en)).toBe('Chapter 3: 沒有旗的船')
    expect(chapterLabel(5, '', en)).toBe('Chapter 5')
    expect(chapterLabel(5, '', zhCN)).toBe('第5章')
    expect(chapterLabel(1, 'Chapter 1 Start', en)).toBe('Chapter 1 Start')
  })
})

describe('locale-aware formatting', () => {
  const now = new Date('2026-10-14T12:00:00Z')
  const ago = (ms: number) => new Date(now.getTime() - ms)

  it('formats relative times per locale', () => {
    expect(formatRelativeTime(ago(10_000), zhTW, now)).toBe('剛剛')
    expect(formatRelativeTime(ago(5 * 60_000), zhTW, now)).toBe('5 分鐘前')
    expect(formatRelativeTime(ago(3 * 3_600_000), zhTW, now)).toBe('3 小時前')
    expect(formatRelativeTime(ago(2 * 86_400_000), zhTW, now)).toBe('2 天前')
    expect(formatRelativeTime(ago(10_000), zhCN, now)).toBe('刚刚')
    expect(formatRelativeTime(ago(5 * 60_000), zhCN, now)).toBe('5分钟前')
    expect(formatRelativeTime(ago(10_000), en, now)).toBe('just now')
    expect(formatRelativeTime(ago(60_000), en, now)).toBe('1 minute ago')
    expect(formatRelativeTime(ago(5 * 60_000), en, now)).toBe('5 minutes ago')
  })

  it('formats counts per locale', () => {
    expect(formatWordCount(12345, zhTW)).toBe('1.2 萬字')
    expect(formatWordCount(980, zhTW)).toBe('980 字')
    expect(formatWordCount(12345, zhCN)).toBe('1.2 万字')
    expect(formatWordCount(1, en)).toBe('1 word')
    expect(formatWordCount(980, en)).toBe('980 words')
    expect(formatWordCount(12345, en)).toBe('12.3K words')
    expect(formatViewCount(123456789, zhTW)).toBe('1.2 億')
    expect(formatViewCount(54321, zhCN)).toBe('5.4 万')
    expect(formatViewCount(54321, en)).toBe('54.3K')
    expect(formatViewCount(42, en)).toBe('42')
  })

  it('formats durations, statuses and dates per locale', () => {
    expect(formatDuration(3 * 3600 + 5 * 60, zhTW)).toBe('3 小時 5 分鐘')
    expect(formatDuration(3600, zhTW)).toBe('1 小時')
    expect(formatDuration(59, zhTW)).toBe('0 分鐘')
    expect(formatDuration(3600 + 60, en)).toBe('1 hr 1 min')
    expect(formatDuration(2 * 3600, en)).toBe('2 hr')
    expect(novelStatus('ongoing', zhTW)).toEqual({ label: '連載中', type: 'success' })
    expect(novelStatus('completed', zhCN)?.label).toBe('已完结')
    expect(novelStatus('hiatus', en)?.label).toBe('On hiatus')
    expect(novelStatus('unknown', en)).toBeNull()
    expect(formatDateTime('2026-01-05T10:03:00', 'zh-TW')).toBe('2026/01/05 10:03')
    expect(formatDateTime('2026-01-05T10:03:00', 'en')).toBe('01/05/2026, 10:03')
    expect(formatDateTime(null, 'en')).toBe('')
  })
})
