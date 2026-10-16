<template>
  <div ref="root" class="admin-chart relative select-none" :style="{ height: `${height}px` }" data-testid="admin-chart">
    <svg
      v-if="width > 0"
      :width="width"
      :height="height"
      :viewBox="`0 0 ${width} ${height}`"
      role="img"
      :aria-label="ariaLabel"
      class="block overflow-visible"
    >
      <g :transform="`translate(${padLeft},${PAD_TOP})`">
        <g v-for="tick in ticks" :key="tick">
          <line :x1="0" :x2="plotWidth" :y1="y(tick)" :y2="y(tick)" class="admin-chart__grid" />
          <text :x="-6" :y="y(tick)" text-anchor="end" dominant-baseline="middle" class="admin-chart__axis">{{ compactNumber(tick) }}</text>
        </g>
        <template v-for="(label, i) in labels" :key="`x${i}`">
          <text
            v-if="i % stride === 0"
            :x="bandCenter(i, count, plotWidth)"
            :y="plotHeight + 16"
            text-anchor="middle"
            class="admin-chart__axis"
          >{{ label }}</text>
        </template>

        <rect
          v-if="hover >= 0"
          :x="bandWidth * hover"
          :y="0"
          :width="bandWidth"
          :height="plotHeight"
          class="admin-chart__hover-band"
        />

        <template v-if="type === 'bar'">
          <g v-for="(s, si) in series" :key="s.key">
            <rect
              v-for="(value, i) in s.values"
              :key="i"
              :x="barX(i, si)"
              :y="y(value)"
              :width="barWidth"
              :height="Math.max(0, plotHeight - y(value))"
              :fill="s.color"
              rx="1.5"
            />
          </g>
        </template>
        <template v-else>
          <g v-for="s in series" :key="s.key">
            <path v-if="area" :d="areaPath(points(s.values), plotHeight)" :fill="s.color" fill-opacity="0.12" />
            <path :d="linePath(points(s.values))" :stroke="s.color" fill="none" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
            <circle
              v-if="hover >= 0"
              :cx="bandCenter(hover, count, plotWidth)"
              :cy="y(s.values[hover] ?? 0)"
              r="3.5"
              :fill="s.color"
              class="admin-chart__dot"
            />
          </g>
        </template>

        <line :x1="0" :x2="plotWidth" :y1="plotHeight" :y2="plotHeight" class="admin-chart__baseline" />
        <rect
          :x="0"
          :y="0"
          :width="plotWidth"
          :height="plotHeight"
          fill="transparent"
          @pointermove="onPointer"
          @pointerdown="onPointer"
          @pointerleave="hover = -1"
        />
      </g>
    </svg>
    <div
      v-if="hover >= 0"
      class="admin-chart__tooltip"
      :style="tooltipStyle"
      data-testid="admin-chart-tooltip"
    >
      <div class="font-medium mb-1">{{ tooltipTitles?.[hover] ?? labels[hover] }}</div>
      <div v-for="s in series" :key="s.key" class="flex items-center gap-1.5 whitespace-nowrap">
        <span class="inline-block w-2 h-2 rounded-full" :style="{ background: s.color }" />
        <span>{{ s.label }}</span>
        <span class="ml-auto pl-3 font-medium">{{ format(s.values[hover] ?? 0) }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// A small dependency-free SVG chart: line/area or grouped columns over equal
// x bands (one per day), with a 0-based "nice" y axis and a hover tooltip.
// Colours come from the series; axes use currentColor so it works on light
// and dark backgrounds.
import { areaPath, bandCenter, compactNumber, indexAt, labelStride, linePath, niceTicks, scaleY, type ChartPoint } from '~/utils/charts'

export interface ChartSeries {
  key: string
  label: string
  color: string
  values: number[]
}

const props = withDefaults(defineProps<{
  type?: 'line' | 'bar'
  labels: string[]
  /** Tooltip headings per point (e.g. full dates); defaults to the labels. */
  tooltipTitles?: string[]
  series: ChartSeries[]
  height?: number
  area?: boolean
  /** Whole-number y ticks (counts). */
  integer?: boolean
  formatValue?: (value: number) => string
  ariaLabel?: string
}>(), {
  type: 'line',
  tooltipTitles: undefined,
  height: 160,
  area: true,
  integer: true,
  formatValue: undefined,
  ariaLabel: undefined,
})

const PAD_TOP = 8
const PAD_RIGHT = 8
const PAD_BOTTOM = 24

const root = ref<HTMLElement | null>(null)
const { width } = useElementSize(root)
const hover = ref(-1)

const count = computed(() => props.labels.length)
const maxValue = computed(() => Math.max(0, ...props.series.flatMap(s => s.values)))
const ticks = computed(() => niceTicks(maxValue.value, props.height < 140 ? 3 : 4, props.integer))
const domainMax = computed(() => ticks.value[ticks.value.length - 1] ?? 1)
const padLeft = computed(() => 10 + 6.5 * Math.max(1, ...ticks.value.map(t => compactNumber(t).length)))
const plotWidth = computed(() => Math.max(0, width.value - padLeft.value - PAD_RIGHT))
const plotHeight = computed(() => Math.max(0, props.height - PAD_TOP - PAD_BOTTOM))
const bandWidth = computed(() => (count.value ? plotWidth.value / count.value : 0))
const stride = computed(() => labelStride(count.value, plotWidth.value))

// Grouped columns take 70% of a band, split between the series.
const barWidth = computed(() => Math.max(1, (bandWidth.value * 0.7) / Math.max(1, props.series.length)))
function barX(index: number, seriesIndex: number) {
  return bandWidth.value * index + bandWidth.value * 0.15 + barWidth.value * seriesIndex
}

function y(value: number) {
  return scaleY(value, domainMax.value, plotHeight.value)
}

function points(values: number[]): ChartPoint[] {
  return values.map((v, i) => ({ x: bandCenter(i, count.value, plotWidth.value), y: y(v) }))
}

function format(value: number) {
  return props.formatValue ? props.formatValue(value) : value.toLocaleString()
}

function onPointer(event: PointerEvent) {
  const rect = (event.currentTarget as SVGRectElement).getBoundingClientRect()
  hover.value = indexAt(event.clientX - rect.left, count.value, rect.width)
}

// Beside the hovered band, flipped to the left in the right half.
const tooltipStyle = computed(() => {
  const x = padLeft.value + bandCenter(hover.value, count.value, plotWidth.value)
  const right = x > width.value / 2
  return {
    left: `${right ? x - 10 : x + 10}px`,
    top: `${PAD_TOP}px`,
    transform: right ? 'translateX(-100%)' : undefined,
  }
})

watch(() => props.labels, () => { hover.value = -1 })
</script>

<style scoped>
.admin-chart__grid {
  stroke: currentColor;
  stroke-opacity: 0.1;
}
.admin-chart__baseline {
  stroke: currentColor;
  stroke-opacity: 0.3;
}
.admin-chart__axis {
  fill: currentColor;
  fill-opacity: 0.55;
  font-size: 11px;
}
.admin-chart__hover-band {
  fill: currentColor;
  fill-opacity: 0.06;
}
.admin-chart__dot {
  stroke: #fff;
  stroke-width: 1.5;
}
.admin-chart__tooltip {
  position: absolute;
  z-index: 10;
  pointer-events: none;
  padding: 6px 10px;
  border-radius: 6px;
  font-size: 12px;
  line-height: 1.5;
  color: #fff;
  background: rgba(30, 30, 30, 0.88);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}
</style>
