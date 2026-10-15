import { describe, expect, it } from 'vitest'
import {
  clipToHalfPlane,
  constrainCurlPoint,
  curlCorner,
  curlGeometry,
  curlLift,
  curlPoint,
  polygonArea,
  polygonClipPath,
  reflectAcross,
} from '~/utils/pageCurl'

const W = 400
const H = 600
const BOTTOM = { x: W, y: H }
const square = [{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }, { x: 0, y: 10 }]

describe('polygon helpers', () => {
  it('clips a polygon to a half-plane', () => {
    const right = clipToHalfPlane(square, { x: 4, y: 0 }, { x: 1, y: 0 })
    expect(polygonArea(right)).toBeCloseTo(60)
    expect(clipToHalfPlane(square, { x: 20, y: 0 }, { x: 1, y: 0 })).toEqual([])
    expect(polygonArea(clipToHalfPlane(square, { x: -5, y: 0 }, { x: 1, y: 0 }))).toBeCloseTo(100)
  })

  it('reflects points across a line', () => {
    expect(reflectAcross({ x: 7, y: 3 }, { x: 5, y: 0 }, { x: 1, y: 0 })).toEqual({ x: 3, y: 3 })
    const p = reflectAcross({ x: 2, y: 0 }, { x: 0, y: 0 }, { x: Math.SQRT1_2, y: Math.SQRT1_2 })
    expect(p.x).toBeCloseTo(0)
    expect(p.y).toBeCloseTo(-2)
  })

  it('writes clip-path polygons in px and hides everything for an empty polygon', () => {
    expect(polygonClipPath([{ x: 0, y: 0 }, { x: 10.04, y: 0 }, { x: 0, y: 5 }])).toBe('polygon(0.0px 0.0px, 10.0px 0.0px, 0.0px 5.0px)')
    expect(polygonClipPath([])).toBe('polygon(0 0, 0 0, 0 0)')
  })
})

describe('curlGeometry', () => {
  it('is flat (null) before the corner moves', () => {
    expect(curlGeometry(W, H, BOTTOM, BOTTOM)).toBeNull()
  })

  it('folds a straight edge vertically halfway between the corner and the pointer', () => {
    const g = curlGeometry(W, H, BOTTOM, { x: 200, y: H })!
    expect(g.foldOrigin.x).toBe(300)
    expect(g.depth).toBe(100)
    expect(g.angle).toBeCloseTo(0)
    expect(polygonArea(g.flat)).toBeCloseTo(300 * H)
    // The back of the page lies mirrored between the pointer and the fold.
    expect(polygonArea(g.flap)).toBeCloseTo(100 * H)
    for (const p of g.flap) {
      expect(p.x).toBeGreaterThanOrEqual(200 - 1e-6)
      expect(p.x).toBeLessThanOrEqual(300 + 1e-6)
    }
  })

  it('conserves the page area for a diagonal fold from the corner', () => {
    const g = curlGeometry(W, H, BOTTOM, { x: 250, y: 480 })!
    const folded = W * H - polygonArea(g.flat)
    expect(polygonArea(g.flap)).toBeCloseTo(folded)
    expect(polygonArea(g.flap)).toBeGreaterThan(0)
    // The corner lands on the pointer.
    expect(g.flap.some(p => Math.hypot(p.x - 250, p.y - 480) < 1e-6)).toBe(true)
  })

  it('has turned the page over completely at the end of the turn', () => {
    const g = curlGeometry(W, H, BOTTOM, curlPoint(1, W, H, BOTTOM))!
    expect(polygonArea(g.flat)).toBeCloseTo(0)
    for (const p of g.flap) expect(p.x).toBeLessThanOrEqual(1e-6)
  })
})

describe('curl motion', () => {
  it('moves the corner across the page with progress', () => {
    expect(curlPoint(0, W, H, BOTTOM)).toEqual({ x: W, y: H })
    expect(curlPoint(0.5, W, H, BOTTOM)).toEqual({ x: 0, y: H })
    expect(curlPoint(1, W, H, BOTTOM)).toEqual({ x: -W, y: H })
    expect(curlPoint(3, W, H, BOTTOM)).toEqual({ x: -W, y: H })
  })

  it('keeps the corner within reach of the spine', () => {
    const p = constrainCurlPoint(W, H, BOTTOM, { x: -W, y: 0 })
    expect(Math.hypot(p.x, p.y - H)).toBeLessThanOrEqual(W + 1e-6)
    const q = constrainCurlPoint(W, H, BOTTOM, { x: 100, y: 500 })
    expect(q).toEqual({ x: 100, y: 500 })
  })

  it('lifts a click-started corner in an arc toward the middle of the page', () => {
    expect(curlLift(0, H, BOTTOM)).toBeCloseTo(0)
    expect(curlLift(1, H, BOTTOM)).toBeCloseTo(0)
    expect(curlLift(0.5, H, BOTTOM)).toBeCloseTo(-0.12 * H)
    expect(curlLift(0.5, H, { x: W, y: 0 })).toBeCloseTo(0.12 * H)
  })

  it('pulls the top or bottom corner, or folds straight from the middle', () => {
    expect(curlCorner(50, W, H)).toEqual({ corner: { x: W, y: 0 }, followY: true })
    expect(curlCorner(550, W, H)).toEqual({ corner: { x: W, y: H }, followY: true })
    expect(curlCorner(300, W, H)).toEqual({ corner: { x: W, y: H }, followY: false })
  })
})
