import { describe, expect, it } from 'vitest'
import {
  anchorParagraph,
  clampPage,
  dragProgress,
  effectivePageAnimation,
  firstVisibleParagraph,
  pageKeyDirection,
  pageLayout,
  pageOfParagraph,
  pageRange,
  pageScrollOffset,
  settleDuration,
  shouldCommitTurn,
  tapZone,
  turnTarget,
  wheelDirection,
  type PageRange,
} from '~/utils/pagination'
import { PAGE_ANIMATIONS } from '~/utils/readingSettings'

describe('pageLayout', () => {
  it('centres an 800px sheet on a wide screen and makes column + gap one page wide', () => {
    const l = pageLayout({ width: 1280, height: 800, margin: 16 })
    expect(l.columnWidth).toBe(768)
    expect(l.columnWidth + l.columnGap).toBe(l.pageWidth)
    expect(l.insetLeft).toBe(256)
    expect(l.contentTop).toBe(40)
    expect(l.contentHeight).toBe(800 - 40 - 36)
  })

  it('uses the margin setting on a phone', () => {
    const l = pageLayout({ width: 390, height: 844, margin: 24 })
    expect(l.columnWidth).toBe(342)
    expect(l.insetLeft).toBe(24)
    expect(l.columnWidth + l.columnGap).toBe(390)
  })

  it('keeps a usable column and whole pixels for odd sizes and huge margins', () => {
    const l = pageLayout({ width: 300.7, height: 200.4, margin: 64 })
    expect(l.pageWidth).toBe(300)
    expect(l.columnWidth).toBe(172)
    expect(Number.isInteger(l.insetLeft)).toBe(true)
    const tiny = pageLayout({ width: 120, height: 100, margin: 64 })
    expect(tiny.columnWidth).toBe(120)
    expect(tiny.columnGap).toBe(0)
    expect(tiny.contentHeight).toBe(100)
    expect(tiny.contentTop).toBe(0)
  })
})

describe('pageRange', () => {
  const W = 400
  it('maps a box within one column to its page', () => {
    expect(pageRange(0, 360, W)).toEqual({ start: 0, end: 0 })
    expect(pageRange(800, 1160, W)).toEqual({ start: 2, end: 2 })
  })

  it('spans the columns of a paragraph split across pages', () => {
    expect(pageRange(0, 760, W)).toEqual({ start: 0, end: 1 })
    expect(pageRange(400, 1560, W)).toEqual({ start: 1, end: 3 })
  })

  it('tolerates sub-pixel edges', () => {
    expect(pageRange(399.6, 759.2, W)).toEqual({ start: 1, end: 1 })
    expect(pageRange(-0.4, 360, W)).toEqual({ start: 0, end: 0 })
  })
})

// p0: page 0; p1: pages 0-1; p2: page 1; p3: pages 1-3 (covers page 2 entirely); p4: page 3.
const RANGES: PageRange[] = [
  { start: 0, end: 0 },
  { start: 0, end: 1 },
  { start: 1, end: 1 },
  { start: 1, end: 3 },
  { start: 3, end: 3 },
]

describe('paragraph <-> page mapping', () => {
  it('opens the page a paragraph starts on', () => {
    expect(RANGES.map((_, i) => pageOfParagraph(RANGES, i))).toEqual([0, 0, 1, 1, 3])
  })

  it('clamps out-of-range and invalid paragraph indexes', () => {
    expect(pageOfParagraph(RANGES, 99)).toBe(3)
    expect(pageOfParagraph(RANGES, -3)).toBe(0)
    expect(pageOfParagraph(RANGES, Number.NaN)).toBe(0)
    expect(pageOfParagraph([], 4)).toBe(0)
  })

  it('finds the first visible paragraph, including one continued from the previous page', () => {
    expect([0, 1, 2, 3].map(p => firstVisibleParagraph(RANGES, p))).toEqual([0, 1, 3, 3])
    expect(firstVisibleParagraph(RANGES, 9)).toBe(4)
  })

  it('anchors a page to a paragraph that maps back to the same page', () => {
    const anchors = [0, 1, 2, 3].map(p => anchorParagraph(RANGES, p))
    expect(anchors).toEqual([0, 2, 3, 4])
    // Saving and restoring is stable, except a page inside one long paragraph,
    // which opens where that paragraph starts.
    expect(anchors.map(i => pageOfParagraph(RANGES, i))).toEqual([0, 1, 1, 3])
    for (const page of [0, 1, 3]) {
      expect(pageOfParagraph(RANGES, anchorParagraph(RANGES, page))).toBe(page)
    }
  })

  it('reports progress like the scroll fraction', () => {
    expect(pageScrollOffset(0, 12)).toBe(0)
    expect(pageScrollOffset(11, 12)).toBe(1)
    expect(pageScrollOffset(3, 5)).toBe(0.75)
    expect(pageScrollOffset(0, 1)).toBe(1)
    expect(pageScrollOffset(40, 5)).toBe(1)
  })

  it('clamps page numbers', () => {
    expect(clampPage(-1, 4)).toBe(0)
    expect(clampPage(7, 4)).toBe(3)
    expect(clampPage(2.7, 4)).toBe(2)
    expect(clampPage(Number.NaN, 4)).toBe(0)
    expect(clampPage(3, 0)).toBe(0)
  })
})

describe('turning', () => {
  it('stops at the first and last page (the neighbouring chapter takes over)', () => {
    expect(turnTarget(0, 1, 3)).toBe(1)
    expect(turnTarget(2, 1, 3)).toBeNull()
    expect(turnTarget(0, -1, 3)).toBeNull()
    expect(turnTarget(2, -1, 3)).toBe(1)
  })

  it('commits a drag that went far enough or was flung, and not one flung back', () => {
    const base = { width: 400, direction: 1 as const }
    expect(shouldCommitTurn({ ...base, distance: -100, velocity: 0 })).toBe(true)
    expect(shouldCommitTurn({ ...base, distance: -40, velocity: 0 })).toBe(false)
    expect(shouldCommitTurn({ ...base, distance: -30, velocity: -0.8 })).toBe(true)
    expect(shouldCommitTurn({ ...base, distance: -200, velocity: 0.6 })).toBe(false)
    expect(shouldCommitTurn({ ...base, distance: 50, velocity: -0.8 })).toBe(false)
    expect(shouldCommitTurn({ width: 400, direction: -1, distance: 120, velocity: 0 })).toBe(true)
    expect(shouldCommitTurn({ width: 400, direction: -1, distance: -120, velocity: 0 })).toBe(false)
  })

  it('maps drags to progress for each animation', () => {
    expect(dragProgress(-200, 400, 1, 'slide')).toBe(0.5)
    expect(dragProgress(-200, 400, 1, 'curl')).toBe(0.25)
    expect(dragProgress(200, 400, -1, 'curl')).toBe(0.5)
    expect(dragProgress(100, 400, 1, 'cover')).toBe(0)
    expect(dragProgress(-900, 400, 1, 'slide')).toBe(1)
  })

  it('settles in proportion to the remaining distance, never instantly', () => {
    expect(settleDuration(1)).toBe(300)
    expect(settleDuration(0.5)).toBe(150)
    expect(settleDuration(0.01)).toBe(120)
  })

  it('splits taps into thirds', () => {
    expect(tapZone(10, 900)).toBe(-1)
    expect(tapZone(450, 900)).toBe(0)
    expect(tapZone(890, 900)).toBe(1)
  })

  it('maps page keys, wheel directions and nothing else', () => {
    expect(['ArrowRight', 'ArrowDown', 'PageDown', ' '].map(key => pageKeyDirection({ key }))).toEqual([1, 1, 1, 1])
    expect(['ArrowLeft', 'ArrowUp', 'PageUp'].map(key => pageKeyDirection({ key }))).toEqual([-1, -1, -1])
    expect(pageKeyDirection({ key: ' ', shiftKey: true })).toBe(-1)
    expect(pageKeyDirection({ key: 'a' })).toBeNull()
    expect(wheelDirection(0, 120)).toBe(1)
    expect(wheelDirection(-30, 4)).toBe(-1)
    expect(wheelDirection(0.2, -0.5)).toBeNull()
  })
})

describe('effectivePageAnimation', () => {
  it('uses the setting when motion is fine', () => {
    for (const a of PAGE_ANIMATIONS) {
      expect(effectivePageAnimation(a, { reducedMotion: false, curlSupported: true })).toBe(a)
    }
  })

  it('turns pages instantly when the user prefers reduced motion', () => {
    for (const a of PAGE_ANIMATIONS) {
      expect(effectivePageAnimation(a, { reducedMotion: true, curlSupported: true })).toBe('none')
    }
  })

  it('falls back from curl to cover without clip-path support', () => {
    expect(effectivePageAnimation('curl', { reducedMotion: false, curlSupported: false })).toBe('cover')
    expect(effectivePageAnimation('slide', { reducedMotion: false, curlSupported: false })).toBe('slide')
    expect(effectivePageAnimation('curl', { reducedMotion: true, curlSupported: false })).toBe('none')
  })
})
