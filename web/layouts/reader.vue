<template>
  <div
    class="min-h-screen"
    :style="{
      backgroundColor: readerThemes[settings.theme]?.bg || '#ffffff',
      color: readerThemes[settings.theme]?.text || '#333333',
    }"
  >
    <slot />
  </div>
</template>

<script setup lang="ts">
import { useReaderStore } from '~/stores/reader'

const readerStore = useReaderStore()
const settings = computed(() => readerStore.settings)

const readerThemes: Record<string, { bg: string; text: string }> = {
  white: { bg: '#ffffff', text: '#333333' },
  yellow: { bg: '#f5f0e0', text: '#4a4a4a' },
  green: { bg: '#e0f0e0', text: '#3a4a3a' },
  dark: { bg: '#2c2c2c', text: '#c0c0c0' },
  black: { bg: '#000000', text: '#808080' },
}
</script>
