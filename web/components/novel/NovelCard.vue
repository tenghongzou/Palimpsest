<template>
  <n-card hoverable class="cursor-pointer" data-testid="novel-card" @click="navigateTo(`/novel/${novel.id}`)">
    <div class="flex gap-3">
      <NovelCover :src="novel.cover_url" :alt="novel.title" :width="80" :height="110" />
      <div class="flex flex-col justify-between flex-1 min-w-0">
        <div>
          <div class="font-semibold text-base truncate">{{ novel.title }}</div>
          <div class="text-sm text-gray-500 mt-1">{{ novel.author_name }}</div>
          <div class="text-xs text-gray-400 mt-1 line-clamp-2">{{ novel.description }}</div>
        </div>
        <div class="flex items-center gap-2 mt-2 flex-wrap">
          <n-tag :type="statusType" size="small">{{ statusLabel }}</n-tag>
          <span class="text-xs text-gray-400">{{ formatWordCount(novel.total_words ?? 0) }}</span>
          <n-rate :value="novel.avg_rating ?? 0" readonly size="small" :count="5" allow-half />
        </div>
      </div>
    </div>
  </n-card>
</template>

<script setup lang="ts">
import { NCard, NTag, NRate } from 'naive-ui'
import type { Novel } from '~/types/novel'
import { formatWordCount } from '~/utils/format'

const props = defineProps<{
  novel: Pick<Novel, 'id' | 'title' | 'author_name' | 'status'> & Partial<Novel>
}>()

const statusMap: Record<string, { label: string, type: 'success' | 'warning' | 'info' }> = {
  ongoing: { label: '連載中', type: 'success' },
  completed: { label: '已完結', type: 'info' },
  hiatus: { label: '暫停', type: 'warning' },
}

const statusLabel = computed(() => statusMap[props.novel.status]?.label || props.novel.status)
const statusType = computed(() => statusMap[props.novel.status]?.type || 'info')
</script>
