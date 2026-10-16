import { describe, expect, it } from 'vitest'
import {
  formatPercent, isQuietPeriod, secondsToHours, seriesTotal, seriesValue, seriesValues, shareWidths, shortDate, utcOffsetMinutes,
} from '~/utils/adminStats'

function day(date: string, overrides: Record<string, number> = {}) {
  return {
    date,
    new_users: 0,
    active_readers: 0,
    reads: 0,
    reading_seconds: 0,
    new_reviews: 0,
    new_comments: 0,
    bookshelf_adds: 0,
    ...overrides,
  }
}

const days = [
  day('2026-10-14', { active_readers: 10, reads: 40, reading_seconds: 5400, new_users: 2 }),
  day('2026-10-15', { active_readers: 12, reads: 55, reading_seconds: 1800, new_reviews: 1 }),
  day('2026-10-16', { active_readers: 8, reads: 30, reading_seconds: 0, bookshelf_adds: 4 }),
]

describe('trend series', () => {
  it('converts reading time to hours with one decimal', () => {
    expect(secondsToHours(3600)).toBe(1)
    expect(secondsToHours(5400)).toBe(1.5)
    expect(secondsToHours(100)).toBe(0)
    expect(secondsToHours(400)).toBe(0.1)
  })

  it('reads a series per day, oldest first', () => {
    expect(seriesValues(days, 'reads')).toEqual([40, 55, 30])
    expect(seriesValues(days, 'reading_hours')).toEqual([1.5, 0.5, 0])
    expect(seriesValue(days[2]!, 'bookshelf_adds')).toBe(4)
  })

  it('sums a series over the period', () => {
    expect(seriesTotal(days, 'reads')).toBe(125)
    expect(seriesTotal(days, 'reading_hours')).toBe(2)
    expect(seriesTotal([], 'reads')).toBe(0)
  })

  it('recognises a period without activity', () => {
    expect(isQuietPeriod(days)).toBe(false)
    expect(isQuietPeriod([day('2026-10-01'), day('2026-10-02')])).toBe(true)
    expect(isQuietPeriod([])).toBe(true)
  })
})

describe('formatting', () => {
  it('shortens API dates without shifting the day', () => {
    expect(shortDate('2026-01-01')).toBe('01/01')
    expect(shortDate('2026-10-16')).toBe('10/16')
    expect(shortDate('bogus')).toBe('bogus')
  })

  it('formats a share as a percentage', () => {
    expect(formatPercent(0.4234, 'en')).toBe('42.3%')
    expect(formatPercent(0, 'en')).toBe('0%')
    expect(formatPercent(1.5, 'en')).toBe('100%')
    expect(formatPercent(undefined)).toBe('—')
  })

  it('scales distribution bars to the largest value', () => {
    expect(shareWidths([200, 100, 1, 0])).toEqual([100, 50, 2, 0])
    expect(shareWidths([])).toEqual([])
    expect(shareWidths([0, 0])).toEqual([0, 0])
  })

  it('sends the UTC offset east of UTC', () => {
    const utc8 = { getTimezoneOffset: () => -480 } as Date
    const utcMinus5 = { getTimezoneOffset: () => 300 } as Date
    expect(utcOffsetMinutes(utc8)).toBe(480)
    expect(utcOffsetMinutes(utcMinus5)).toBe(-300)
  })
})
