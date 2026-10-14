import { describe, expect, it } from 'vitest'
import { chapterLabel } from '~/utils/format'

describe('chapterLabel', () => {
  it('adds the number only when the title lacks one', () => {
    expect(chapterLabel(3, '沒有旗的船')).toBe('第3章 沒有旗的船')
    expect(chapterLabel(3, '第三章 沒有旗的船')).toBe('第三章 沒有旗的船')
    expect(chapterLabel(12, '第12章 歸來')).toBe('第12章 歸來')
    expect(chapterLabel(1, '第一回 起')).toBe('第一回 起')
    expect(chapterLabel(5, '')).toBe('第5章')
    expect(chapterLabel(2, '第一次見面')).toBe('第2章 第一次見面')
  })
})
