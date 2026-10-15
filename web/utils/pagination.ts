// Page mode of the reader: the chapter is laid out with CSS multi-column
// layout, one column per page, and the reader shows one column at a time.
// These helpers are the pure parts: page geometry, paragraph <-> page mapping,
// turn decisions and the choice of animation.
import type { PageAnimation } from '~/utils/readingSettings'

/** Widest text column, as in scroll mode (ReaderContent's max-width). */
export const MAX_TEXT_WIDTH = 800
/** Strip above the text with the chapter title. */
export const PAGE_HEADER_HEIGHT = 40
/** Strip below the text with the page number. */
export const PAGE_FOOTER_HEIGHT = 36
/** Duration of a page turn started by a click or key. */
export const TURN_DURATION_MS = 300
/** A pointer that moves less than this is a tap, not a drag. */
export const DRAG_THRESHOLD_PX = 8

export interface PageLayoutInput {
  /** Size of the page area (the viewport in practice). */
  width: number
  height: number
  /** The reader's margin setting: horizontal space on each side of the text. */
  margin: number
  maxTextWidth?: number
  headerHeight?: number
  footerHeight?: number
}

export interface PageLayout {
  pageWidth: number
  pageHeight: number
  /** Width of the text on a page (one CSS column). */
  columnWidth: number
  /**
   * Gap between columns. columnWidth + columnGap === pageWidth, so page n
   * starts exactly n * pageWidth from the first one.
   */
  columnGap: number
  /** Left edge of the text on every page. */
  insetLeft: number
  contentTop: number
  contentHeight: number
}

/** Page geometry for a viewport; whole pixels so pages never drift. */
export function pageLayout(input: PageLayoutInput): PageLayout {
  const pageWidth = Math.max(1, Math.floor(input.width))
  const pageHeight = Math.max(1, Math.floor(input.height))
  const margin = Math.max(0, input.margin)
  const header = input.headerHeight ?? PAGE_HEADER_HEIGHT
  const footer = input.footerHeight ?? PAGE_FOOTER_HEIGHT
  const sheet = Math.min(pageWidth, input.maxTextWidth ?? MAX_TEXT_WIDTH)
  // Keep a usable column even with a large margin on a narrow screen.
  const columnWidth = Math.min(pageWidth, Math.max(Math.min(160, pageWidth), Math.floor(sheet - 2 * margin)))
  const columnGap = pageWidth - columnWidth
  const contentHeight = Math.max(Math.min(120, pageHeight), pageHeight - header - footer)
  return {
    pageWidth,
    pageHeight,
    columnWidth,
    columnGap,
    insetLeft: Math.floor(columnGap / 2),
    contentTop: Math.min(header, pageHeight - contentHeight),
    contentHeight,
  }
}

/** The pages a box spans, from its left and right edges relative to the first page. */
export interface PageRange {
  start: number
  end: number
}

/**
 * Pages a laid-out element spans. `left`/`right` are its bounding box edges
 * relative to the start of the column flow; a paragraph split over several
 * columns spans from its first to its last column.
 */
export function pageRange(left: number, right: number, pageWidth: number): PageRange {
  const w = Math.max(1, pageWidth)
  const start = Math.max(0, Math.floor((left + 1) / w))
  const end = Math.max(start, Math.floor((Math.max(left, right) - 1) / w))
  return { start, end }
}

export function clampPage(page: number, pageCount: number): number {
  if (!Number.isFinite(page)) return 0
  return Math.min(Math.max(0, pageCount - 1), Math.max(0, Math.trunc(page)))
}

/** The page on which paragraph `index` starts (a bookmark or saved position). */
export function pageOfParagraph(ranges: readonly PageRange[], index: number): number {
  if (!ranges.length) return 0
  const i = Math.min(ranges.length - 1, Math.max(0, Math.trunc(Number.isFinite(index) ? index : 0)))
  return ranges[i]!.start
}

/** The first paragraph visible on `page`, possibly continued from the page before. */
export function firstVisibleParagraph(ranges: readonly PageRange[], page: number): number {
  const i = ranges.findIndex(r => r.end >= page)
  return i >= 0 ? i : Math.max(0, ranges.length - 1)
}

/**
 * The paragraph that stands for `page` in saved progress and bookmarks: the
 * first one starting on it, or the one covering the whole page. Unlike the
 * first visible paragraph (which may have started on the previous page), it
 * maps back to the same page, so saving and restoring never moves the reader
 * back a page.
 */
export function anchorParagraph(ranges: readonly PageRange[], page: number): number {
  const starting = ranges.findIndex(r => r.start === page)
  if (starting >= 0) return starting
  return firstVisibleParagraph(ranges, page)
}

/** Progress through the chapter, 0 on the first page and 1 on the last, like the scroll fraction. */
export function pageScrollOffset(page: number, pageCount: number): number {
  if (pageCount <= 1) return 1
  return Math.min(1, Math.max(0, clampPage(page, pageCount) / (pageCount - 1)))
}

export type TurnDirection = 1 | -1

/** The page a turn leads to, or null past the first/last page (the previous/next chapter). */
export function turnTarget(page: number, direction: TurnDirection, pageCount: number): number | null {
  const next = page + direction
  return next >= 0 && next < pageCount ? next : null
}

/**
 * Whether a released drag completes the turn: a fling in the turn direction
 * does, a fling back cancels it, otherwise it must have moved far enough.
 * `distance` and `velocity` (px/ms) are horizontal and signed; turning to
 * the next page drags to the left (negative).
 */
export function shouldCommitTurn(opts: { distance: number, velocity: number, width: number, direction: TurnDirection }): boolean {
  const along = -opts.direction * opts.distance
  const speed = -opts.direction * opts.velocity
  if (speed > 0.35) return along > 0
  if (speed < -0.35) return false
  return along > Math.max(24, opts.width * 0.18)
}

/** Time to finish (or undo) a turn from the current progress; never a jarring snap. */
export function settleDuration(remaining: number, full = TURN_DURATION_MS): number {
  return Math.round(Math.max(120, full * Math.min(1, Math.abs(remaining))))
}

/** Left third: previous page, right third: next page, middle: toolbar (0). */
export function tapZone(x: number, width: number): -1 | 0 | 1 {
  const f = width > 0 ? x / width : 0.5
  if (f < 1 / 3) return -1
  if (f > 2 / 3) return 1
  return 0
}

/** Page-turning keys in page mode, or null for other keys. */
export function pageKeyDirection(e: { key: string, shiftKey?: boolean }): TurnDirection | null {
  switch (e.key) {
    case 'ArrowRight':
    case 'ArrowDown':
    case 'PageDown':
      return 1
    case 'ArrowLeft':
    case 'ArrowUp':
    case 'PageUp':
      return -1
    case ' ':
    case 'Spacebar':
      return e.shiftKey ? -1 : 1
    default:
      return null
  }
}

/** Direction of a wheel event (vertical wins), or null for a negligible delta. */
export function wheelDirection(deltaX: number, deltaY: number): TurnDirection | null {
  const d = Math.abs(deltaY) >= Math.abs(deltaX) ? deltaY : deltaX
  if (Math.abs(d) < 1) return null
  return d > 0 ? 1 : -1
}

/**
 * The animation actually used: none when the user prefers reduced motion,
 * and cover where the curl cannot be drawn (no clip-path support).
 */
export function effectivePageAnimation(setting: PageAnimation, env: { reducedMotion: boolean, curlSupported: boolean }): PageAnimation {
  if (env.reducedMotion) return 'none'
  if (setting === 'curl' && !env.curlSupported) return 'cover'
  return setting
}

/**
 * Turn progress (0..1) for a horizontal drag of `dx` px. The curl's corner
 * follows the finger, so turning forward needs the corner to cross the page
 * twice (it ends at -width); turning back it starts there, so the finger
 * drives it at double speed. Slide and cover move one page width.
 */
export function dragProgress(dx: number, width: number, direction: TurnDirection, animation: PageAnimation): number {
  const w = Math.max(1, width)
  const along = -direction * dx
  const span = animation === 'curl' && direction === 1 ? 2 * w : w
  return Math.min(1, Math.max(0, along / span))
}

export const easeOutCubic = (t: number) => 1 - (1 - t) ** 3
export const easeInOutCubic = (t: number) => (t < 0.5 ? 4 * t ** 3 : 1 - (-2 * t + 2) ** 3 / 2)
