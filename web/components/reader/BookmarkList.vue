<template>
  <div class="space-y-2" data-testid="bookmark-list">
    <div
      v-for="b in bookmarks"
      :key="b.id"
      class="flex items-start gap-3 p-3 rounded border border-gray-200 hover:bg-gray-50/50"
      data-testid="bookmark-item"
    >
      <div class="flex-1 min-w-0 cursor-pointer" @click="emit('open', b)">
        <div class="text-sm font-medium truncate">
          {{ b.chapter_title || $t('reader.bookmarks.chapterFallback') }}<span class="text-gray-400 font-normal"> · {{ $t('reader.paragraph.label', { n: b.paragraph_index + 1 }) }}</span>
        </div>
        <div v-if="b.note" class="text-sm text-gray-600 mt-1 whitespace-pre-wrap break-words">{{ b.note }}</div>
        <div class="text-xs text-gray-400 mt-1">
          {{ formatDateTime(b.created_at) }}
          <span v-if="!b.is_synced" class="ml-1">· {{ $t('reader.bookmarks.notSynced') }}</span>
        </div>
      </div>
      <n-popconfirm @positive-click="emit('remove', b)">
        <template #trigger>
          <n-button size="tiny" quaternary type="error" @click.stop>{{ $t('common.delete') }}</n-button>
        </template>
        {{ $t('reader.bookmarks.confirmDelete') }}
      </n-popconfirm>
    </div>
    <div v-if="!bookmarks.length && emptyText" class="text-sm text-gray-400 py-4 text-center">{{ emptyText }}</div>
  </div>
</template>

<script setup lang="ts">
import { NButton, NPopconfirm } from 'naive-ui'
import type { LocalBookmark } from '~/utils/localDb'
defineProps<{
  bookmarks: LocalBookmark[]
  emptyText?: string
}>()

const emit = defineEmits<{
  open: [bookmark: LocalBookmark]
  remove: [bookmark: LocalBookmark]
}>()

const { formatDateTime } = useFormat()
</script>
