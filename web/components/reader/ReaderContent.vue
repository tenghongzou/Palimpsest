<template>
  <div
    class="reader-content mx-auto"
    :style="{
      fontSize: `${settings.fontSize}px`,
      lineHeight: settings.lineHeight,
      letterSpacing: `${settings.letterSpacing}px`,
      fontFamily: fontFamilyValue,
      maxWidth: '800px',
      padding: `24px ${settings.margin}px`,
    }"
  >
    <h2 class="text-center mb-8 font-bold text-xl">{{ title }}</h2>
    <!-- Text is rendered as plain text nodes; chapter content is never treated as HTML. -->
    <div class="text-justify" data-testid="reader-paragraphs">
      <p
        v-for="(p, i) in paragraphs"
        :key="i"
        :data-p="i"
        class="reader-paragraph"
        :class="{ 'reader-paragraph--highlight': i === highlight }"
        style="text-indent: 2em; margin-bottom: 0.8em;"
      >{{ p }}</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { FONT_FAMILIES } from '~/utils/readingSettings'
import { splitParagraphs } from '~/utils/text'

const props = defineProps<{
  content: string
  title?: string
  /** Paragraph to briefly highlight (e.g. after jumping to a bookmark). */
  highlight?: number | null
  settings: {
    fontSize: number
    lineHeight: number
    letterSpacing: number
    margin: number
    fontFamily: string
  }
}>()

const fontFamilyValue = computed(() => (FONT_FAMILIES[props.settings.fontFamily] ?? FONT_FAMILIES.system).css)
const paragraphs = computed(() => splitParagraphs(props.content))
</script>

<style scoped>
.reader-paragraph {
  transition: background-color 0.6s;
  border-radius: 4px;
}
.reader-paragraph--highlight {
  background-color: rgba(250, 204, 21, 0.25);
}
</style>
