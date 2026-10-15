// Geometry of the simulated page curl. The turning page is folded along the
// perpendicular bisector of its dragged corner C and the point P the corner
// has been pulled to: the part beyond the fold (around C) is flipped over,
// so its back shows mirrored across the fold, lying on the page near P.
// Everything is in page pixels with the spine (binding) on the left edge.

export interface Point {
  x: number
  y: number
}

export type Polygon = Point[]

/**
 * Clips a convex polygon to the half-plane (p - origin) . normal >= 0
 * (Sutherland-Hodgman against one edge).
 */
export function clipToHalfPlane(polygon: Polygon, origin: Point, normal: Point): Polygon {
  const side = (p: Point) => (p.x - origin.x) * normal.x + (p.y - origin.y) * normal.y
  const out: Polygon = []
  for (let i = 0; i < polygon.length; i++) {
    const a = polygon[i]!
    const b = polygon[(i + 1) % polygon.length]!
    const sa = side(a)
    const sb = side(b)
    if (sa >= 0) out.push(a)
    if ((sa >= 0) !== (sb >= 0)) {
      const t = sa / (sa - sb)
      out.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t })
    }
  }
  return out
}

/** Mirror image of `p` across the line through `origin` perpendicular to unit `normal`. */
export function reflectAcross(p: Point, origin: Point, normal: Point): Point {
  const d = 2 * ((p.x - origin.x) * normal.x + (p.y - origin.y) * normal.y)
  return { x: p.x - d * normal.x, y: p.y - d * normal.y }
}

/**
 * Keeps the pulled corner where paper could actually be: no farther from the
 * spine end of its edge than the page width, and no farther from the other
 * spine corner than the page diagonal (the page cannot stretch or tear).
 */
export function constrainCurlPoint(width: number, height: number, corner: Point, p: Point): Point {
  let q = { ...p }
  const limits: [Point, number][] = [
    [{ x: 0, y: corner.y }, width],
    [{ x: 0, y: height - corner.y }, Math.hypot(width, height)],
  ]
  for (const [anchor, radius] of limits) {
    const dx = q.x - anchor.x
    const dy = q.y - anchor.y
    const dist = Math.hypot(dx, dy)
    if (dist > radius && dist > 0) q = { x: anchor.x + dx * radius / dist, y: anchor.y + dy * radius / dist }
  }
  return q
}

/**
 * Where the corner is at turn progress `t` (0: flat, 1: turned over onto the
 * left of the spine). `lift` raises or lowers it off its edge.
 */
export function curlPoint(t: number, width: number, height: number, corner: Point, lift = 0): Point {
  const p = { x: width - 2 * width * Math.min(1, Math.max(0, t)), y: corner.y + lift }
  return constrainCurlPoint(width, height, corner, p)
}

/** The lift of a click-started curl: the corner rises in an arc and lands again. */
export function curlLift(t: number, height: number, corner: Point): number {
  const up = corner.y > height / 2 ? -1 : 1
  return up * Math.sin(Math.PI * Math.min(1, Math.max(0, t))) * height * 0.12
}

/** The corner a drag starting at `y` pulls; from the middle band the fold stays vertical (followY false). */
export function curlCorner(y: number, width: number, height: number): { corner: Point, followY: boolean } {
  if (y < height / 3) return { corner: { x: width, y: 0 }, followY: true }
  if (y > (2 * height) / 3) return { corner: { x: width, y: height }, followY: true }
  return { corner: { x: width, y: height }, followY: false }
}

export interface CurlGeometry {
  /** The part of the turning page still lying flat (spine side of the fold). */
  flat: Polygon
  /** The flipped-over part: the back of the page, mirrored across the fold. */
  flap: Polygon
  /** A point on the fold line (midpoint of the corner and where it was pulled). */
  foldOrigin: Point
  /** Angle (radians) of the fold's normal pointing to the corner side. */
  angle: number
  /** Distance from the fold to the pulled corner: the depth of the flap. */
  depth: number
}

/** Fold geometry of a page `width` x `height` with `corner` pulled to `p`; null while flat. */
export function curlGeometry(width: number, height: number, corner: Point, p: Point): CurlGeometry | null {
  const dx = corner.x - p.x
  const dy = corner.y - p.y
  const len = Math.hypot(dx, dy)
  if (len < 0.5) return null
  const normal = { x: dx / len, y: dy / len }
  const origin = { x: (corner.x + p.x) / 2, y: (corner.y + p.y) / 2 }
  const page: Polygon = [{ x: 0, y: 0 }, { x: width, y: 0 }, { x: width, y: height }, { x: 0, y: height }]
  const flat = clipToHalfPlane(page, origin, { x: -normal.x, y: -normal.y })
  const folded = clipToHalfPlane(page, origin, normal)
  return {
    flat,
    flap: folded.map(q => reflectAcross(q, origin, normal)),
    foldOrigin: origin,
    angle: Math.atan2(normal.y, normal.x),
    depth: len / 2,
  }
}

/** A CSS clip-path for a polygon in px; an empty polygon clips everything away. */
export function polygonClipPath(polygon: Polygon): string {
  if (polygon.length < 3) return 'polygon(0 0, 0 0, 0 0)'
  return `polygon(${polygon.map(p => `${p.x.toFixed(1)}px ${p.y.toFixed(1)}px`).join(', ')})`
}

/** Signed area (shoelace); used by tests to check the fold conserves the page. */
export function polygonArea(polygon: Polygon): number {
  let a = 0
  for (let i = 0; i < polygon.length; i++) {
    const p = polygon[i]!
    const q = polygon[(i + 1) % polygon.length]!
    a += p.x * q.y - q.x * p.y
  }
  return Math.abs(a) / 2
}
