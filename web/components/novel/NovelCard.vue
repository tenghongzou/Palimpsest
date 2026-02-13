<template>
  <n-card hoverable class="cursor-pointer" @click="navigateTo(`/novel/${novel.id}`)">
    <div class="flex gap-3">
      <n-image
        :src="novel.cover_url || '/placeholder-cover.png'"
        :alt="novel.title"
        width="80"
        height="110"
        object-fit="cover"
        class="rounded flex-shrink-0"
        lazy
        preview-disabled
      />
      <div class="flex flex-col justify-between flex-1 min-w-0">
        <div>
          <div class="font-semibold text-base truncate">{{ novel.title }}</div>
          <div class="text-sm text-gray-500 mt-1">{{ novel.author_name }}</div>
          <div class="text-xs text-gray-400 mt-1 line-clamp-2">{{ novel.description }}</div>
        </div>
        <div class="flex items-center gap-2 mt-2">
          <n-tag :type="statusType" size="small">{{ statusLabel }}</n-tag>
          <span class="text-xs text-gray-400">{{ formatWordCount(novel.total_words) }}</span>
          <n-rate :value="novel.avg_rating" readonly size="small" :count="5" allow-half />
        </div>
      </div>
    </div>
  </n-card>
</template>

<script setup lang="ts">
import { NCard, NImage, NTag, NRate } from 'naive-ui'
import type { Novel } from '~/types/novel'

const props = defineProps<{
  novel: Novel
}>()

const statusMap: Record<string, { label: string; type: 'success' | 'warning' | 'info' }> = {
  ongoing: { label: '連載中', type: 'success' },
  completed: { label: '已完結', type: 'info' },
  hiatus: { label: '暫停', type: 'warning' },
}

const statusLabel = computed(() => statusMap[props.novel.status]?.label || props.novel.status)
const statusType = computed(() => statusMap[props.novel.status]?.type || 'info')

function formatWordCount(count: number): string {
  if (count >= 10000) return `${(count / 10000).toFixed(1)}萬字`
  return `${count}字`
}
</script>
