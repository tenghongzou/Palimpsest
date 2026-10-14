<template>
  <div class="fixed bottom-0 left-0 right-0 z-50 transition-transform" :class="visible ? 'translate-y-0' : 'translate-y-full'" @click.stop>
    <div class="max-w-3xl mx-auto px-4 pb-4">
      <n-card size="small" class="shadow-lg">
        <div class="flex items-center justify-between">
          <n-button text :disabled="!hasPrev" @click="emit('prev')">
            <template #icon><n-icon :component="ChevronBack" /></template>
            上一章
          </n-button>

          <div class="flex items-center gap-3">
            <n-button text circle title="目錄" aria-label="目錄" data-testid="toolbar-toc" @click="emit('openChapterList')">
              <template #icon><n-icon :component="ListOutline" /></template>
            </n-button>
            <n-button text circle title="閱讀設定" aria-label="閱讀設定" data-testid="toolbar-settings" @click="emit('openSettings')">
              <template #icon><n-icon :component="SettingsOutline" /></template>
            </n-button>
            <n-button text circle title="書籤" aria-label="書籤" data-testid="toolbar-bookmarks" @click="emit('openBookmarks')">
              <template #icon><n-icon :component="bookmarked ? Bookmark : BookmarkOutline" /></template>
            </n-button>
            <n-button text circle title="留言" aria-label="留言" data-testid="toolbar-comments" @click="emit('openComments')">
              <template #icon><n-icon :component="ChatbubbleEllipsesOutline" /></template>
            </n-button>
            <n-button text circle title="翻譯" aria-label="翻譯" data-testid="toolbar-translate" @click="emit('translate')">
              <template #icon><n-icon :component="LanguageOutline" /></template>
            </n-button>
          </div>

          <n-button text :disabled="!hasNext" @click="emit('next')">
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
  ChevronBack, ChevronForward, Bookmark, ChatbubbleEllipsesOutline,
  ListOutline, SettingsOutline, BookmarkOutline, LanguageOutline,
} from '@vicons/ionicons5'

defineProps<{
  visible: boolean
  hasPrev?: boolean
  hasNext?: boolean
  bookmarked?: boolean
}>()

const emit = defineEmits<{
  prev: []
  next: []
  openSettings: []
  openChapterList: []
  openBookmarks: []
  openComments: []
  translate: []
}>()
</script>
