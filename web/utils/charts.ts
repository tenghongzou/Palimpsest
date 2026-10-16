// Pure geometry for the small hand-rolled SVG charts (components/admin/AdminChart.vue).

/** A "nice" step (1, 2, 2.5 or 5 × 10^k) of at least `raw`. */
export function niceStep(raw: number, integer = false): number {
  if (!Number.isFinite(raw) || raw <= 0) return 1
  const magnitude = 10 ** Math.floor(Math.log10(raw))
  const residual = raw / magnitude
  const factor = residual <= 1 ? 1 : residual <= 2 ? 2 : residual <= 2.5 ? 2.5 : residual <= 5 ? 5 : 10
  const step = factor * magnitude
  if (!integer) return step
  // 2.5 is not an integer step; skip to 5 at that magnitude, and never below 1.
  return Math.max(1, Number.isInteger(step) ? step : Math.ceil(step / magnitude / 5) * 5 * magnitude)
}

/**
 * Y-axis ticks from 0 covering `max` with about `count` intervals. With
 * `integer`, ticks are whole numbers (counts); an all-zero series still gets
 * a 0..count axis so the line sits on the baseline.
 */
export function niceTicks(max: number, count = 4, integer = true): number[] {
  const top = Number.isFinite(max) && max > 0 ? max : 0
  const intervals = Math.max(1, Math.round(count))
  const step = top === 0 ? (integer ? 1 : 0.25) : niceStep(top / intervals, integer)
  const n = top === 0 ? intervals : Math.max(1, Math.ceil(top / step - 1e-9))
  // Round away float noise such as 0.30000000000000004.
  return Array.from({ length: n + 1 }, (_, i) => Number((i * step).toPrecision(12)))
}

/** Maps a value in 0..domainMax onto pixel rows (0 = top) of a plot `height` tall. */
export function scaleY(value: number, domainMax: number, height: number): number {
  if (domainMax <= 0) return height
  const clamped = Math.min(Math.max(value, 0), domainMax)
  return height - (clamped / domainMax) * height
}

/** The x centre of point `index` of `count` spread across `width` (bands of equal width). */
export function bandCenter(index: number, count: number, width: number): number {
  if (count <= 0) return 0
  const band = width / count
  return band * index + band / 2
}

/** The point index under pixel `x` for `count` equal bands across `width`. */
export function indexAt(x: number, count: number, width: number): number {
  if (count <= 0 || width <= 0) return -1
  return Math.min(count - 1, Math.max(0, Math.floor((x / width) * count)))
}

/** Show every n-th x label so labels about `minLabelWidth` wide do not overlap. */
export function labelStride(count: number, width: number, minLabelWidth = 44): number {
  if (count <= 0 || width <= 0) return 1
  const fits = Math.max(1, Math.floor(width / minLabelWidth))
  return Math.max(1, Math.ceil(count / fits))
}

export interface ChartPoint { x: number, y: number }

/** An SVG path through the points (straight segments). */
export function linePath(points: ChartPoint[]): string {
  return points.map((p, i) => `${i === 0 ? 'M' : 'L'}${round(p.x)},${round(p.y)}`).join(' ')
}

/** A closed SVG path filling the area between the points and `baseline`. */
export function areaPath(points: ChartPoint[], baseline: number): string {
  if (!points.length) return ''
  const first = points[0]!
  const last = points[points.length - 1]!
  return `${linePath(points)} L${round(last.x)},${round(baseline)} L${round(first.x)},${round(baseline)} Z`
}

/** Compact axis label: 1200 → 1.2k, 3500000 → 3.5M. */
export function compactNumber(value: number): string {
  const abs = Math.abs(value)
  if (abs >= 1e6) return `${trim(value / 1e6)}M`
  if (abs >= 1e3) return `${trim(value / 1e3)}k`
  return trim(value)
}

function trim(value: number): string {
  return String(Number(value.toFixed(value % 1 === 0 ? 0 : 1)))
}

function round(value: number): number {
  return Math.round(value * 10) / 10
}
