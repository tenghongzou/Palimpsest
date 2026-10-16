import { describe, expect, it } from 'vitest'
import { areaPath, bandCenter, compactNumber, indexAt, labelStride, linePath, niceStep, niceTicks, scaleY } from '~/utils/charts'

describe('niceStep', () => {
  it('rounds up to 1, 2, 2.5, 5 or 10 times a power of ten', () => {
    expect(niceStep(0.8)).toBe(1)
    expect(niceStep(1.3)).toBe(2)
    expect(niceStep(2.2)).toBe(2.5)
    expect(niceStep(3)).toBe(5)
    expect(niceStep(7)).toBe(10)
    expect(niceStep(130)).toBe(200)
    expect(niceStep(0.03)).toBeCloseTo(0.05)
  })

  it('keeps integer steps whole', () => {
    expect(niceStep(2.2, true)).toBe(5)
    expect(niceStep(0.3, true)).toBe(1)
    expect(niceStep(22, true)).toBe(25)
  })

  it('falls back to 1 for non-positive input', () => {
    expect(niceStep(0)).toBe(1)
    expect(niceStep(Number.NaN)).toBe(1)
  })
})

describe('niceTicks', () => {
  it('covers the maximum from zero', () => {
    expect(niceTicks(87)).toEqual([0, 25, 50, 75, 100])
    expect(niceTicks(10)).toEqual([0, 5, 10])
    expect(niceTicks(1234)).toEqual([0, 500, 1000, 1500])
  })

  it('uses whole numbers for small counts', () => {
    expect(niceTicks(3)).toEqual([0, 1, 2, 3])
    expect(niceTicks(1)).toEqual([0, 1])
  })

  it('allows fractional ticks for non-integer series', () => {
    expect(niceTicks(1.2, 4, false)).toEqual([0, 0.5, 1, 1.5])
  })

  it('draws an axis for an all-zero series', () => {
    expect(niceTicks(0)).toEqual([0, 1, 2, 3, 4])
    expect(niceTicks(0, 4, false)).toEqual([0, 0.25, 0.5, 0.75, 1])
    expect(niceTicks(-5)).toEqual([0, 1, 2, 3, 4])
  })
})

describe('scales', () => {
  it('maps values to rows with 0 at the bottom', () => {
    expect(scaleY(0, 100, 200)).toBe(200)
    expect(scaleY(100, 100, 200)).toBe(0)
    expect(scaleY(25, 100, 200)).toBe(150)
    expect(scaleY(500, 100, 200)).toBe(0)
    expect(scaleY(-3, 100, 200)).toBe(200)
    expect(scaleY(5, 0, 200)).toBe(200)
  })

  it('centres points in equal bands and finds the band under a pointer', () => {
    expect(bandCenter(0, 4, 400)).toBe(50)
    expect(bandCenter(3, 4, 400)).toBe(350)
    expect(indexAt(0, 4, 400)).toBe(0)
    expect(indexAt(120, 4, 400)).toBe(1)
    expect(indexAt(399, 4, 400)).toBe(3)
    expect(indexAt(450, 4, 400)).toBe(3)
    expect(indexAt(-10, 4, 400)).toBe(0)
    expect(indexAt(10, 0, 400)).toBe(-1)
  })

  it('thins x labels so they fit', () => {
    expect(labelStride(7, 600)).toBe(1)
    expect(labelStride(30, 600)).toBe(3)
    expect(labelStride(90, 300)).toBe(15)
    expect(labelStride(0, 300)).toBe(1)
  })
})

describe('paths', () => {
  it('builds line and area paths', () => {
    const points = [{ x: 0, y: 10 }, { x: 5.55, y: 2 }, { x: 10, y: 0 }]
    expect(linePath(points)).toBe('M0,10 L5.6,2 L10,0')
    expect(areaPath(points, 20)).toBe('M0,10 L5.6,2 L10,0 L10,20 L0,20 Z')
    expect(areaPath([], 20)).toBe('')
  })

  it('abbreviates axis labels', () => {
    expect(compactNumber(0)).toBe('0')
    expect(compactNumber(0.5)).toBe('0.5')
    expect(compactNumber(950)).toBe('950')
    expect(compactNumber(1000)).toBe('1k')
    expect(compactNumber(1500)).toBe('1.5k')
    expect(compactNumber(2_500_000)).toBe('2.5M')
  })
})
