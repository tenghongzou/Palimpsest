<template>
  <div class="fixed bottom-0 left-0 right-0 z-50 transition-transform" :class="visible ? 'translate-y-0' : 'translate-y-full'" @click.stop>
    <div class="max-w-3xl mx-auto px-4 pb-4">
      <n-card size="small" class="shadow-lg">
        <div class="flex items-center justify-between">
          <n-button text :disabled="!hasPrev" @click="emit('prev')">
            <template #icon><n-icon :component="ChevronBack" /></template>
            {{ $t('reader.prevChapter') }}
          </n-button>

          <div class="flex items-center gap-3">
            <n-button text circle :title="$t('reader.toolbar.toc')" :aria-label="$t('reader.toolbar.toc')" data-testid="toolbar-toc" @click="emit('openChapterList')">
              <template #icon><n-icon :component="ListOutline" /></template>
            </n-button>
            <n-button text circle :title="$t('reader.toolbar.settings')" :aria-label="$t('reader.toolbar.settings')" data-testid="toolbar-settings" @click="emit('openSettings')">
              <template #icon><n-icon :component="SettingsOutline" /></template>
            </n-button>
            <n-button text circle :title="$t('reader.toolbar.bookmarks')" :aria-label="$t('reader.toolbar.bookmarks')" data-testid="toolbar-bookmarks" @click="emit('openBookmarks')">
              <template #icon><n-icon :component="bookmarked ? Bookmark : BookmarkOutline" /></template>
            </n-button>
            <n-button text circle :title="$t('reader.toolbar.comments')" :aria-label="$t('reader.toolbar.comments')" data-testid="toolbar-comments" @click="emit('openComments')">
              <template #icon><n-icon :component="ChatbubbleEllipsesOutline" /></template>
            </n-button>
            <n-button text circle :title="$t('reader.toolbar.translate')" :aria-label="$t('reader.toolbar.translate')" data-testid="toolbar-translate" @click="emit('translate')">
              <template #icon><n-icon :component="LanguageOutline" /></template>
            </n-button>
          </div>

          <n-button text :disabled="!hasNext" @click="emit('next')">
            {{ $t('reader.nextChapter') }}
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
