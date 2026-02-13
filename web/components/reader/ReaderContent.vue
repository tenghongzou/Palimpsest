<template>
  <div
    class="reader-content mx-auto"
    :style="{
      fontSize: `${settings.fontSize}px`,
      lineHeight: settings.lineHeight,
      letterSpacing: `${settings.letterSpacing}px`,
      fontFamily: fontFamilyValue,
      maxWidth: `${800 - settings.margin * 2}px`,
      padding: `24px ${settings.margin}px`,
    }"
  >
    <h2 class="text-center mb-8 font-bold text-xl">{{ title }}</h2>
    <div
      class="whitespace-pre-wrap text-justify"
      v-html="formattedContent"
    />
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  content: string
  title?: string
  settings: {
    fontSize: number
    lineHeight: number
    letterSpacing: number
    margin: number
    fontFamily: string
  }
}>()

const fontFamilies: Record<string, string> = {
  system: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  serif: '"Noto Serif TC", "Noto Serif SC", serif',
  kai: '"KaiTi", "楷体", serif',
  song: '"SimSun", "宋体", serif',
}

const fontFamilyValue = computed(() => fontFamilies[props.settings.fontFamily] || fontFamilies.system)

const formattedContent = computed(() => {
  if (!props.content) return ''
  return props.content
    .split('\n')
    .map(p => p.trim())
    .filter(Boolean)
    .map(p => `<p style="text-indent: 2em; margin-bottom: 0.8em;">${p}</p>`)
    .join('')
})
</script>
