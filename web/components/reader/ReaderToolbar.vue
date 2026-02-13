<template>
  <div class="fixed bottom-0 left-0 right-0 z-50 transition-transform" :class="visible ? 'translate-y-0' : 'translate-y-full'">
    <div class="max-w-3xl mx-auto px-4 pb-4">
      <n-card size="small" class="shadow-lg">
        <div class="flex items-center justify-between">
          <n-button text @click="emit('prev')">
            <template #icon><n-icon :component="ChevronBack" /></template>
            上一章
          </n-button>

          <div class="flex items-center gap-3">
            <n-button text circle @click="emit('openChapterList')">
              <template #icon><n-icon :component="ListOutline" /></template>
            </n-button>
            <n-button text circle @click="emit('openSettings')">
              <template #icon><n-icon :component="SettingsOutline" /></template>
            </n-button>
            <n-button text circle @click="emit('toggleBookmark')">
              <template #icon><n-icon :component="BookmarkOutline" /></template>
            </n-button>
            <n-button text circle @click="emit('translate')">
              <template #icon><n-icon :component="LanguageOutline" /></template>
            </n-button>
          </div>

          <n-button text @click="emit('next')">
            下一章
            <template #icon><n-icon :component="ChevronForward" /></template>
          </n-button>
        </div>
      </n-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NCard, NButton, NIcon } from 'naive-ui'
import {
  ChevronBack, ChevronForward,
  ListOutline, SettingsOutline, BookmarkOutline, LanguageOutline,
} from '@vicons/ionicons5'

defineProps<{
  visible: boolean
}>()

const emit = defineEmits<{
  prev: []
  next: []
  openSettings: []
  openChapterList: []
  toggleBookmark: []
  translate: []
}>()
</script>
