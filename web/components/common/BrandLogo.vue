<template>
  <svg
    xmlns="http://www.w3.org/2000/svg"
    :viewBox="`0 0 ${layout.width} ${layout.height}`"
    :width="width"
    :height="height"
    :role="decorative ? undefined : 'img'"
    :aria-label="decorative ? undefined : label"
    :aria-hidden="decorative ? 'true' : undefined"
    class="brand-logo"
    :style="color ? { color } : undefined"
    focusable="false"
  >
    <defs>
      <linearGradient :id="gradientId" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" :stop-color="MARK_GRADIENT[0]" />
        <stop offset="1" :stop-color="MARK_GRADIENT[1]" />
      </linearGradient>
    </defs>
    <g :transform="layout.markX ? `translate(${layout.markX} 0)` : undefined">
      <rect :width="MARK_SIZE" :height="MARK_SIZE" :rx="MARK_RADIUS" :fill="`url(#${gradientId})`" />
      <g transform="translate(256 272)">
        <path
          v-for="(shape, i) in MARK_SHAPES"
          :key="i"
          :fill="shape.fill"
          :fill-rule="shape.evenodd ? 'evenodd' : undefined"
          :d="shape.d"
        />
      </g>
    </g>
    <path v-if="layout.wordmark" fill="currentColor" :transform="layout.wordmark" :d="WORDMARK_PATH" />
  </svg>
</template>

<script setup lang="ts">
import { computed, useId } from 'vue'
import {
  BRAND_LAYOUTS, MARK_GRADIENT, MARK_RADIUS, MARK_SHAPES, MARK_SIZE,
  WORDMARK_COLOR, WORDMARK_PATH,
} from '~/utils/brandLogo'
import type { BrandLogoVariant } from '~/utils/brandLogo'

interface Props {
  variant?: BrandLogoVariant
  /** Rendered height in px; the width follows the logo's aspect ratio. */
  height?: number
  /**
   * Wordmark colour: `light` / `dark` use the brand colours for light or dark
   * backgrounds, `inherit` follows the surrounding text colour (currentColor).
   */
  tone?: 'light' | 'dark' | 'inherit'
  /** Accessible name; the brand name is not translated. */
  label?: string
  /** Hide from assistive technology when the name is already given nearby. */
  decorative?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'horizontal',
  height: 32,
  tone: 'light',
  label: 'Palimpsest',
  decorative: false,
})

const layout = computed(() => BRAND_LAYOUTS[props.variant])
const width = computed(() => Math.round(props.height * layout.value.width / layout.value.height * 100) / 100)
const color = computed(() => (props.tone === 'inherit' ? undefined : WORDMARK_COLOR[props.tone]))

// Unique per instance so several logos on one page don't share (or lose) the gradient.
const gradientId = `brand-logo-${useId().replace(/[^\w-]/g, '-')}`
</script>

<style scoped>
/* No `display` here: callers toggle it with utility classes (hidden, sm:block). */
.brand-logo {
  flex-shrink: 0;
  vertical-align: middle;
}
</style>
