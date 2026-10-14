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
        :class="{ 'reader-paragraph--highlight': i === highlight, 'reader-paragraph--active': i === activeParagraph }"
        style="text-indent: 2em; margin-bottom: 0.8em;"
      >{{ p }}<template v-if="commentCounts"><button
        v-if="commentCounts[i]"
        type="button"
        class="para-comment para-comment--count"
        :aria-label="`第 ${i + 1} 段有 ${commentCounts[i]} 則評論，開啟段落評論`"
        :title="`${commentCounts[i]} 則段落評論`"
        data-testid="paragraph-comment-count"
        @click.stop="emit('openParagraphComments', i)"
      >{{ commentCounts[i] > 99 ? '99+' : commentCounts[i] }}</button><button
        v-else
        type="button"
        class="para-comment para-comment--add"
        :aria-label="`評論第 ${i + 1} 段`"
        title="評論這一段"
        data-testid="paragraph-comment-add"
        @click.stop="emit('openParagraphComments', i)"
      ><n-icon :component="ChatbubbleOutline" aria-hidden="true" /></button></template></p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NIcon } from 'naive-ui'
import { ChatbubbleOutline } from '@vicons/ionicons5'
import { FONT_FAMILIES } from '~/utils/readingSettings'
import { splitParagraphs } from '~/utils/text'
import type { ParagraphCounts } from '~/utils/paragraphComments'

const props = defineProps<{
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
}>()

const emit = defineEmits<{
  openParagraphComments: [index: number]
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
