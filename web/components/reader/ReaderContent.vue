<template>
  <div
    class="reader-content"
    :class="paged ? 'reader-content--paged' : 'mx-auto'"
    :style="rootStyle"
  >
    <h2 class="text-center mb-8 font-bold text-xl">{{ title }}</h2>
    <!-- Text is rendered as plain text nodes; chapter content is never treated as HTML. -->
    <div class="text-justify" :data-testid="primary ? 'reader-paragraphs' : undefined">
      <p
        v-for="(p, i) in paragraphs"
        :key="i"
        :data-p="i"
        class="reader-paragraph"
        :class="{ 'reader-paragraph--highlight': i === highlight, 'reader-paragraph--active': i === activeParagraph }"
        style="text-indent: 2em; margin-bottom: 0.8em;"
      >{{ p }}<template v-if="commentCounts"><button
        v-if="commentCounts[i]"
        type="button"
        class="para-comment para-comment--count"
        :aria-label="$t('reader.paragraph.countAria', { n: i + 1, count: commentCounts[i] })"
        :title="$t('reader.paragraph.countTitle', { count: commentCounts[i] }, commentCounts[i])"
        :data-testid="primary ? 'paragraph-comment-count' : undefined"
        @click.stop="emit('openParagraphComments', i)"
      >{{ commentCounts[i] > 99 ? '99+' : commentCounts[i] }}</button><button
        v-else
        type="button"
        class="para-comment para-comment--add"
        :aria-label="$t('reader.paragraph.addAria', { n: i + 1 })"
        :title="$t('reader.paragraph.addTitle')"
        :data-testid="primary ? 'paragraph-comment-add' : undefined"
        @click.stop="emit('openParagraphComments', i)"
      ><n-icon :component="ChatbubbleOutline" aria-hidden="true" /></button></template></p>
    </div>
    <template v-if="paged">
      <slot name="end" />
      <!-- Marks the end of the column flow: its column is the last page. -->
      <div class="reader-flow-end" data-flow-end />
    </template>
  </div>
</template>

<script setup lang="ts">
import { NIcon } from 'naive-ui'
import { ChatbubbleOutline } from '@vicons/ionicons5'
import { FONT_FAMILIES } from '~/utils/readingSettings'
import { splitParagraphs } from '~/utils/text'
import type { ParagraphCounts } from '~/utils/paragraphComments'
import type { PageLayout } from '~/utils/pagination'

const props = withDefaults(defineProps<{
  content: string
  title?: string
  /** Paragraph to briefly highlight (e.g. after jumping to a bookmark). */
  highlight?: number | null
  /** Paragraph whose comments are open; it stays marked meanwhile. */
  activeParagraph?: number | null
  /**
   * Comment counts by paragraph index. Null hides the paragraph comment
   * markers and buttons (offline, counts not loaded, or misaligned text).
   */
  commentCounts?: ParagraphCounts | null
  settings: {
    fontSize: number
    lineHeight: number
    letterSpacing: number
    margin: number
    fontFamily: string
  }
  /**
   * Page mode: lay the text out in columns of this geometry (one column per
   * page) and show page `pageIndex`. Unset for scroll mode.
   */
  paged?: PageLayout | null
  pageIndex?: number
  /** False for the extra copies page mode renders while turning (no test ids). */
  primary?: boolean
}>(), { highlight: null, activeParagraph: null, commentCounts: null, paged: null, pageIndex: 0, primary: true })

const emit = defineEmits<{
  openParagraphComments: [index: number]
}>()

const fontFamilyValue = computed(() => (FONT_FAMILIES[props.settings.fontFamily] ?? FONT_FAMILIES.system).css)
const paragraphs = computed(() => splitParagraphs(props.content))

const rootStyle = computed(() => {
  const s = props.settings
  const typography = {
    fontSize: `${s.fontSize}px`,
    lineHeight: s.lineHeight,
    letterSpacing: `${s.letterSpacing}px`,
    fontFamily: fontFamilyValue.value,
  }
  const p = props.paged
  if (!p) return { ...typography, maxWidth: '800px', padding: `24px ${s.margin}px` }
  return {
    ...typography,
    left: `${p.insetLeft}px`,
    top: `${p.contentTop}px`,
    width: `${p.columnWidth}px`,
    height: `${p.contentHeight}px`,
    columnWidth: `${p.columnWidth}px`,
    columnGap: `${p.columnGap}px`,
    transform: `translate3d(${-(props.pageIndex ?? 0) * p.pageWidth}px, 0, 0)`,
  }
})
</script>

<style scoped>
/* Page mode: a fixed-height column flow; overflowing columns continue to the right. */
.reader-content--paged {
  position: absolute;
  column-fill: auto;
  box-sizing: border-box;
  padding: 0;
  margin: 0;
}
.reader-content--paged h2 {
  margin-top: 0.4em;
}
.reader-flow-end {
  height: 1px;
}
.reader-paragraph {
  transition: background-color 0.6s;
  border-radius: 4px;
}
.reader-paragraph--highlight {
  background-color: rgba(250, 204, 21, 0.25);
}
.reader-paragraph--active {
  background-color: rgba(128, 128, 128, 0.12);
}

/* Paragraph comment markers: small, in the text color so every reader theme works. */
.para-comment {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  vertical-align: 0.1em;
  margin-left: 0.35em;
  min-width: 1.6em;
  height: 1.35em;
  padding: 0 0.4em;
  border-radius: 999px;
  font-size: 0.62em;
  line-height: 1;
  letter-spacing: 0;
  text-indent: 0;
  color: inherit;
  background: transparent;
  cursor: pointer;
  font-family: inherit;
  transition: opacity 0.2s;
}
.para-comment--count {
  border: 1px solid currentColor;
  opacity: 0.5;
}
.para-comment--add {
  border: 1px dashed transparent;
  font-size: 0.75em;
  opacity: 0;
  pointer-events: none;
}
.para-comment:hover,
.para-comment:focus-visible {
  opacity: 0.95;
}
.para-comment:focus-visible {
  outline: 2px solid currentColor;
  outline-offset: 1px;
}
/* The add button appears on paragraph hover (or tap) and when focused by keyboard. */
.reader-paragraph:hover .para-comment--add,
.reader-paragraph--active .para-comment--add,
.para-comment--add:focus-visible {
  opacity: 0.6;
  pointer-events: auto;
}
.reader-paragraph:hover .para-comment--add:hover {
  opacity: 0.95;
}
@media print {
  .para-comment {
    display: none;
  }
}
</style>
