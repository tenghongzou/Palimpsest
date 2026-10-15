<template>
  <div
    ref="root"
    class="reader-pager"
    :style="{ '--pager-bg': background }"
    data-testid="reader-pager"
    :data-animation="animation"
    @pointerdown="onPointerDown"
    @pointermove="onPointerMove"
    @pointerup="onPointerUp"
    @pointercancel="onPointerCancel"
    @wheel.passive="onWheel"
  >
    <template v-if="layout">
      <!--
        The current page and its neighbours, each a copy of the chapter's column
        flow shifted to its page. Neighbours stay hidden until a turn shows them.
      -->
      <div
        v-for="layer in layers"
        :key="layer"
        class="pager-page"
        :style="layerStyle(layer)"
        :data-page="layer"
        :aria-hidden="layer === page ? undefined : 'true'"
      >
        <div class="pager-header" :style="{ paddingLeft: `${layout.insetLeft}px`, paddingRight: `${layout.insetLeft}px` }">
          {{ title }}
        </div>
        <ReaderContent
          :content="content"
          :title="title"
          :settings="settings"
          :highlight="highlight"
          :active-paragraph="activeParagraph"
          :comment-counts="commentCounts"
          :paged="layout"
          :page-index="layer"
          :primary="layer === page"
          @open-paragraph-comments="onOpenParagraphComments"
        >
          <template #end><slot name="end" /></template>
        </ReaderContent>
      </div>

      <template v-if="curl">
        <!-- Shadow the lifted page casts on the page being uncovered. -->
        <div class="curl-frame" :style="curl.frameStyle" style="z-index: 3">
          <div class="curl-band" :style="curl.shadowStyle" />
        </div>
        <!-- The back of the turning page, mirrored across the fold. -->
        <div class="curl-flap-shadow">
          <div class="curl-flap" :style="curl.flapClip">
            <div class="curl-frame" :style="curl.frameStyle">
              <div class="curl-band" :style="curl.flapStyle" />
            </div>
          </div>
        </div>
      </template>
    </template>

    <div class="pager-status" :style="layout ? { left: `${layout.insetLeft}px` } : undefined">
      <slot name="status" />
    </div>
    <div
      class="pager-indicator"
      role="status"
      :style="layout ? { right: `${layout.insetLeft}px` } : undefined"
      :aria-label="$t('reader.page.indicatorAria', { current: page + 1, total: pageCount })"
      data-testid="reader-page-indicator"
    >
      {{ $t('reader.page.indicator', { current: page + 1, total: pageCount }) }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { useEventListener, useMediaQuery, useResizeObserver } from '@vueuse/core'
import type { ParagraphCounts } from '~/utils/paragraphComments'
import type { PageAnimation, ReaderSettings } from '~/utils/readingSettings'
import {
  DRAG_THRESHOLD_PX,
  TURN_DURATION_MS,
  anchorParagraph,
  clampPage,
  dragProgress,
  easeInOutCubic,
  easeOutCubic,
  effectivePageAnimation,
  pageLayout,
  pageOfParagraph,
  pageRange,
  settleDuration,
  shouldCommitTurn,
  tapZone,
  turnTarget,
  wheelDirection,
  type PageRange,
  type TurnDirection,
} from '~/utils/pagination'
import { curlCorner, curlGeometry, curlLift, curlPoint, polygonClipPath, type Point } from '~/utils/pageCurl'

export interface PagerPosition {
  /** The paragraph standing for the current page (progress, bookmarks). */
  paragraph: number
  page: number
  pageCount: number
}

const props = withDefaults(defineProps<{
  content: string
  title?: string
  settings: ReaderSettings
  /** Page color (the reader theme's background); pages must be opaque to cover each other. */
  background: string
  /** The page animation setting; reduced motion and missing support are applied here. */
  pageAnimation: PageAnimation
  highlight?: number | null
  activeParagraph?: number | null
  commentCounts?: ParagraphCounts | null
}>(), { title: '', highlight: null, activeParagraph: null, commentCounts: null })

const emit = defineEmits<{
  /** The page changed or was laid out again. */
  position: [position: PagerPosition]
  /** A turn past the first (-1) or last (1) page: the previous/next chapter. */
  boundary: [direction: TurnDirection]
  /** A tap in the middle third. */
  toggleToolbar: []
  openParagraphComments: [index: number]
}>()

const root = ref<HTMLElement | null>(null)
const size = reactive({ width: 0, height: 0 })
const page = ref(0)
const pageCount = ref(1)

const reducedMotion = useMediaQuery('(prefers-reduced-motion: reduce)')
const curlSupported = ref(true)
const animation = computed(() => effectivePageAnimation(props.pageAnimation, {
  reducedMotion: reducedMotion.value,
  curlSupported: curlSupported.value,
}))

const layout = computed(() => size.width > 0 && size.height > 0
  ? pageLayout({ width: size.width, height: size.height, margin: props.settings.margin })
  : null)

/** Rendered pages: the current one and its neighbours. */
const layers = computed(() => {
  const out: number[] = []
  for (let p = page.value - 1; p <= page.value + 1; p++) {
    if (p >= 0 && p < pageCount.value) out.push(p)
  }
  return out
})

function onOpenParagraphComments(index: number) {
  emit('openParagraphComments', index)
}

// ------------------------------------------------------------ layout

/** Pages each paragraph spans, from the last measurement. */
let ranges: PageRange[] = []
let measured = false
/** The paragraph kept on screen when the layout changes (resize, settings, translation). */
let anchor = 0
type PendingTarget = { kind: 'paragraph', index: number } | { kind: 'page', page: number } | { kind: 'last' }
/** A jump requested before the first measurement. */
let pending: PendingTarget | null = null

function emitPosition() {
  emit('position', { paragraph: anchor, page: page.value, pageCount: pageCount.value })
}

function setPage(target: number, updateAnchor = true) {
  page.value = clampPage(target, pageCount.value)
  if (updateAnchor) anchor = anchorParagraph(ranges, page.value)
  emitPosition()
}

function measure() {
  const el = root.value
  const L = layout.value
  if (!el || !L) return
  finishTurnNow()
  const flow = el.querySelector<HTMLElement>(`.pager-page[data-page="${page.value}"] .reader-content`)
    ?? el.querySelector<HTMLElement>('.pager-page .reader-content')
  if (!flow) return
  // Relative to the flow, so the page shift (transform) cancels out.
  const base = flow.getBoundingClientRect().left
  ranges = Array.from(flow.querySelectorAll<HTMLElement>('[data-p]')).map((p) => {
    const r = p.getBoundingClientRect()
    return pageRange(r.left - base, r.right - base, L.pageWidth)
  })
  const end = flow.querySelector<HTMLElement>('[data-flow-end]')?.getBoundingClientRect()
  const lastPage = Math.max(
    end ? pageRange(end.left - base, end.right - base, L.pageWidth).start : 0,
    ranges.at(-1)?.end ?? 0,
  )
  pageCount.value = lastPage + 1
  measured = true
  const target = pending
  pending = null
  if (!target) setPage(pageOfParagraph(ranges, anchor), false)
  else if (target.kind === 'paragraph') setPage(pageOfParagraph(ranges, target.index), false)
  else if (target.kind === 'last') setPage(pageCount.value - 1)
  else setPage(target.page)
}

watch(
  () => [
    layout.value, props.content, props.title, props.commentCounts,
    props.settings.fontSize, props.settings.lineHeight, props.settings.letterSpacing, props.settings.fontFamily,
  ],
  () => measure(),
  { flush: 'post' },
)

function readSize() {
  const el = root.value
  if (!el) return
  size.width = Math.floor(el.clientWidth)
  size.height = Math.floor(el.clientHeight)
}
useResizeObserver(root, readSize)

let previousOverflow = ''
onMounted(() => {
  curlSupported.value = typeof CSS !== 'undefined' && CSS.supports('clip-path', 'polygon(0px 0px, 10px 0px, 0px 10px)')
  // Nothing scrolls in page mode; hide the document's scrollbar meanwhile.
  previousOverflow = document.documentElement.style.overflow
  document.documentElement.style.overflow = 'hidden'
  readSize()
  // Web fonts change the text metrics once they arrive.
  document.fonts?.ready.then(() => measure()).catch(() => {})
})
if (import.meta.client && document.fonts) {
  useEventListener(document.fonts, 'loadingdone', () => measure())
}
onBeforeUnmount(() => {
  cancelAnimationFrame(raf)
  document.documentElement.style.overflow = previousOverflow
})

// ------------------------------------------------------------ turning

type TurnSource = 'auto' | 'drag'
interface Turn {
  direction: TurnDirection
  target: number
  /** 0: not started, 1: done. */
  progress: number
  animation: PageAnimation
  source: TurnSource
  /** Curl: the corner being pulled, whether it follows the pointer's height, and by how much. */
  corner: Point
  followY: boolean
  lift: number
}

const turn = shallowRef<Turn | null>(null)
let raf = 0
/** Where the running animation is heading (1 completes the turn). */
let heading: 0 | 1 = 1

function startTurn(direction: TurnDirection, source: TurnSource, pointerY: number): Turn | null {
  const L = layout.value
  const target = turnTarget(page.value, direction, pageCount.value)
  if (!L || target === null) return null
  const { corner, followY } = source === 'auto'
    ? { corner: { x: L.pageWidth, y: L.pageHeight }, followY: false }
    : curlCorner(pointerY, L.pageWidth, L.pageHeight)
  const t: Turn = { direction, target, progress: 0, animation: animation.value, source, corner, followY, lift: 0 }
  turn.value = t
  return t
}

function endTurn(commit: boolean) {
  cancelAnimationFrame(raf)
  const t = turn.value
  turn.value = null
  if (commit && t) setPage(t.target)
}

/** Completes (or undoes) a running animation at once, e.g. when the next turn starts. */
function finishTurnNow() {
  if (!turn.value) return
  endTurn(heading === 1 && !gesture?.dragging)
}

function animateTo(goal: 0 | 1, duration: number, easing: (t: number) => number) {
  cancelAnimationFrame(raf)
  const start = turn.value
  if (!start) return
  heading = goal
  const from = start.progress
  const fromLift = start.lift
  const t0 = performance.now()
  const step = (now: number) => {
    const current = turn.value
    if (!current) return
    const k = Math.min(1, (now - t0) / duration)
    const e = easing(k)
    turn.value = { ...current, progress: from + (goal - from) * e, lift: fromLift * (1 - e) }
    if (k < 1) raf = requestAnimationFrame(step)
    else endTurn(goal === 1)
  }
  raf = requestAnimationFrame(step)
}

/** Turns one page (click, key, wheel); past the ends it asks for the neighbouring chapter. */
function turnPage(direction: TurnDirection) {
  if (!measured || gesture?.dragging) return
  finishTurnNow()
  const target = turnTarget(page.value, direction, pageCount.value)
  if (target === null) {
    emit('boundary', direction)
    return
  }
  if (animation.value === 'none') {
    setPage(target)
    return
  }
  if (!startTurn(direction, 'auto', 0)) return
  const curling = animation.value === 'curl'
  animateTo(1, curling ? TURN_DURATION_MS + 50 : TURN_DURATION_MS, curling ? easeInOutCubic : easeOutCubic)
}

// ------------------------------------------------------------ rendering a turn

const SHADOW = 'rgba(0, 0, 0, 0.28)'

function layerStyle(layer: number): Record<string, string | number> {
  const t = turn.value
  const L = layout.value
  const shown = layer === page.value || (t !== null && layer === t.target)
  if (!shown || !L) return { visibility: 'hidden', zIndex: 0 }
  if (!t) return { zIndex: 2 }
  const W = L.pageWidth
  const p = t.progress
  const isTarget = layer === t.target
  switch (t.animation) {
    case 'slide': {
      const x = isTarget ? t.direction * (1 - p) * W : -t.direction * p * W
      return { zIndex: 2, transform: `translate3d(${x.toFixed(1)}px, 0, 0)`, willChange: 'transform' }
    }
    case 'cover': {
      if (!isTarget) return { zIndex: 2 }
      const x = t.direction * (1 - p) * W
      return {
        zIndex: 3,
        transform: `translate3d(${x.toFixed(1)}px, 0, 0)`,
        boxShadow: `${t.direction === 1 ? -6 : 6}px 0 22px ${SHADOW}`,
        willChange: 'transform',
      }
    }
    case 'curl': {
      // Forward the current page curls away; backward the previous page uncurls onto it.
      const curling = t.direction === 1 ? page.value : t.target
      if (layer !== curling) return { zIndex: 2 }
      const g = curl.value
      return { zIndex: 4, clipPath: g ? g.flatClip : 'none' }
    }
    default:
      return { zIndex: 2 }
  }
}

const curl = computed(() => {
  const t = turn.value
  const L = layout.value
  if (!t || !L || t.animation !== 'curl') return null
  const W = L.pageWidth
  const H = L.pageHeight
  // Geometry of a forward turn; a backward turn plays it in reverse.
  const forward = t.direction === 1 ? t.progress : 1 - t.progress
  const lift = t.source === 'auto' ? curlLift(forward, H, t.corner) : (t.followY ? t.lift : 0)
  const g = curlGeometry(W, H, t.corner, curlPoint(forward, W, H, t.corner, lift))
  if (!g) return null
  const diag = Math.ceil(Math.hypot(W, H))
  const d = Math.max(1, g.depth)
  const shadowWidth = Math.min(90, Math.max(12, d * 0.6))
  const fade = 1 - forward ** 3
  return {
    flatClip: polygonClipPath(g.flat),
    flapClip: { clipPath: polygonClipPath(g.flap) },
    frameStyle: {
      left: `${g.foldOrigin.x.toFixed(1)}px`,
      top: `${g.foldOrigin.y.toFixed(1)}px`,
      transform: `rotate(${g.angle.toFixed(4)}rad)`,
    },
    shadowStyle: {
      left: '0px',
      top: `${-diag}px`,
      height: `${2 * diag}px`,
      width: `${shadowWidth.toFixed(1)}px`,
      opacity: fade.toFixed(3),
      background: `linear-gradient(to right, rgba(0, 0, 0, 0.38), rgba(0, 0, 0, 0.12) 40%, rgba(0, 0, 0, 0))`,
    },
    // Paper back: dark in the crease, a highlight where it bulges, shaded toward the edge.
    flapStyle: {
      left: `${-2 * diag}px`,
      top: `${-diag}px`,
      height: `${2 * diag}px`,
      width: `${2 * diag}px`,
      backgroundColor: 'var(--pager-bg)',
      backgroundImage: `linear-gradient(to left, rgba(0, 0, 0, 0.30) 0px, rgba(0, 0, 0, 0.10) ${(d * 0.06).toFixed(1)}px, `
        + `rgba(255, 255, 255, 0.20) ${(d * 0.32).toFixed(1)}px, rgba(255, 255, 255, 0.04) ${(d * 0.7).toFixed(1)}px, `
        + `rgba(0, 0, 0, 0.14) ${d.toFixed(1)}px, rgba(0, 0, 0, 0.14) 100%)`,
    },
  }
})

// ------------------------------------------------------------ input

interface Gesture {
  id: number
  x0: number
  y0: number
  /** Start height within the pager (picks the curl corner). */
  localY: number
  dragging: boolean
  direction: TurnDirection
  samples: { t: number, x: number }[]
}
let gesture: Gesture | null = null

function isInteractive(target: EventTarget | null): boolean {
  return !!(target as HTMLElement | null)?.closest?.('button, a, input, textarea, select, [role="button"]')
}

function onPointerDown(e: PointerEvent) {
  if (gesture || !measured) return
  if (e.pointerType === 'mouse' && e.button !== 0) return
  if (isInteractive(e.target)) return
  finishTurnNow()
  const rect = root.value!.getBoundingClientRect()
  gesture = {
    id: e.pointerId,
    x0: e.clientX,
    y0: e.clientY,
    localY: e.clientY - rect.top,
    dragging: false,
    direction: 1,
    samples: [{ t: e.timeStamp, x: e.clientX }],
  }
}

function onPointerMove(e: PointerEvent) {
  const g = gesture
  if (!g || e.pointerId !== g.id) return
  const dx = e.clientX - g.x0
  const dy = e.clientY - g.y0
  g.samples.push({ t: e.timeStamp, x: e.clientX })
  if (g.samples.length > 8) g.samples.shift()
  if (!g.dragging) {
    if (Math.hypot(dx, dy) < DRAG_THRESHOLD_PX) return
    if (Math.abs(dx) < Math.abs(dy) * 0.5) {
      // A vertical swipe: neither a tap nor a turn.
      gesture = null
      return
    }
    g.dragging = true
    g.direction = dx < 0 ? 1 : -1
    root.value?.setPointerCapture?.(e.pointerId)
    if (animation.value !== 'none') startTurn(g.direction, 'drag', g.localY)
  }
  const t = turn.value
  const L = layout.value
  if (t && t.source === 'drag' && L) {
    turn.value = { ...t, progress: dragProgress(dx, L.pageWidth, t.direction, t.animation), lift: dy }
  }
}

/** Horizontal speed over the last ~100ms of the gesture, px/ms. */
function velocity(g: Gesture): number {
  const last = g.samples.at(-1)!
  const first = g.samples.find(s => last.t - s.t <= 100) ?? last
  const dt = last.t - first.t
  return dt > 0 ? (last.x - first.x) / dt : 0
}

function onPointerUp(e: PointerEvent) {
  const g = gesture
  if (!g || e.pointerId !== g.id) return
  gesture = null
  const rect = root.value!.getBoundingClientRect()
  if (!g.dragging) {
    const zone = tapZone(e.clientX - rect.left, rect.width)
    if (zone === 0) emit('toggleToolbar')
    else turnPage(zone)
    return
  }
  const dx = e.clientX - g.x0
  const commit = shouldCommitTurn({ distance: dx, velocity: velocity(g), width: rect.width, direction: g.direction })
  const t = turn.value
  if (t && t.source === 'drag') {
    animateTo(commit ? 1 : 0, settleDuration(commit ? 1 - t.progress : t.progress), easeOutCubic)
    return
  }
  if (!commit) return
  const target = turnTarget(page.value, g.direction, pageCount.value)
  if (target === null) emit('boundary', g.direction)
  else setPage(target)
}

function onPointerCancel(e: PointerEvent) {
  const g = gesture
  if (!g || e.pointerId !== g.id) return
  gesture = null
  const t = turn.value
  if (t && t.source === 'drag') animateTo(0, settleDuration(t.progress), easeOutCubic)
}

let wheelLock = 0
let lastWheelTurn = 0

/** One turn per wheel gesture; a long continuous scroll turns again every ~0.9s. */
function onWheel(e: WheelEvent) {
  const direction = wheelDirection(e.deltaX, e.deltaY)
  if (!direction) return
  const now = performance.now()
  if (now < wheelLock) {
    wheelLock = Math.min(lastWheelTurn + 900, Math.max(wheelLock, now + 180))
    return
  }
  lastWheelTurn = now
  wheelLock = now + 350
  turnPage(direction)
}

// ------------------------------------------------------------ API

/** Opens the page on which paragraph `index` starts (bookmarks, saved progress, comments). */
function goToParagraph(index: number) {
  anchor = Math.max(0, Math.trunc(index))
  if (!measured) {
    pending = { kind: 'paragraph', index: anchor }
    return
  }
  finishTurnNow()
  setPage(pageOfParagraph(ranges, anchor), false)
}

/** Opens a page by index, or the last one (entering a chapter backwards). */
function goToPage(target: number | 'last') {
  if (!measured) {
    pending = target === 'last' ? { kind: 'last' } : { kind: 'page', page: target }
    return
  }
  finishTurnNow()
  setPage(target === 'last' ? pageCount.value - 1 : target)
}

defineExpose({ goToParagraph, goToPage, turnPage })
</script>

<style scoped>
.reader-pager {
  position: fixed;
  inset: 0;
  z-index: 1;
  overflow: hidden;
  background: var(--pager-bg);
  user-select: none;
  -webkit-user-select: none;
  -webkit-touch-callout: none;
  touch-action: pinch-zoom;
  overscroll-behavior: none;
}
.pager-page {
  position: absolute;
  inset: 0;
  overflow: hidden;
  background: var(--pager-bg);
  contain: layout paint;
}
.pager-header {
  height: 40px;
  line-height: 40px;
  font-size: 12px;
  opacity: 0.55;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  box-sizing: border-box;
}
.pager-status,
.pager-indicator {
  position: absolute;
  bottom: 0;
  height: 36px;
  line-height: 36px;
  font-size: 12px;
  z-index: 6;
  white-space: nowrap;
}
.pager-indicator {
  opacity: 0.6;
  pointer-events: none;
  font-variant-numeric: tabular-nums;
}
.curl-frame {
  position: absolute;
  width: 0;
  height: 0;
  transform-origin: 0 0;
  pointer-events: none;
}
.curl-band {
  position: absolute;
}
.curl-flap-shadow {
  position: absolute;
  inset: 0;
  z-index: 5;
  pointer-events: none;
  filter: drop-shadow(0 0 6px rgba(0, 0, 0, 0.3));
}
.curl-flap {
  position: absolute;
  inset: 0;
  overflow: hidden;
}
</style>
