<template>
  <div class="space-y-4">
    <div class="flex items-center gap-4">
      <NuxtLink
        v-for="rt in rankingTypes"
        :key="rt.key"
        :to="`/ranking/${rt.key}`"
        class="no-underline"
      >
        <n-tag
          :type="rt.key === rankingType ? 'primary' : 'default'"
          round
          :bordered="rt.key !== rankingType"
          class="cursor-pointer"
        >
          {{ rt.label }}
        </n-tag>
      </NuxtLink>
    </div>

    <n-tabs v-model:value="period" type="segment" @update:value="loadRanking">
      <n-tab-pane name="daily" tab="日榜" />
      <n-tab-pane name="weekly" tab="週榜" />
      <n-tab-pane name="monthly" tab="月榜" />
      <n-tab-pane name="all" tab="總榜" />
    </n-tabs>

    <n-spin :show="loading">
      <div class="space-y-3">
        <div
          v-for="(novel, idx) in novels"
          :key="novel.id"
          class="flex items-center gap-4 cursor-pointer hover:bg-gray-50 p-3 rounded"
          @click="navigateTo(`/novel/${novel.id}`)"
        >
          <span
            class="w-8 h-8 flex items-center justify-center rounded-full text-sm font-bold flex-shrink-0"
            :class="idx < 3 ? 'bg-primary text-white' : 'bg-gray-100 text-gray-500'"
          >
            {{ idx + 1 }}
          </span>
          <div class="flex-1 min-w-0">
            <div class="font-semibold truncate">{{ novel.title }}</div>
            <div class="text-sm text-gray-500">{{ novel.author_name }}</div>
          </div>
          <div class="text-sm text-gray-400 flex-shrink-0">
            {{ formatMetric(novel) }}
          </div>
        </div>
      </div>
      <n-empty v-if="!loading && novels.length === 0" description="暫無排行數據" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NTag, NTabs, NTabPane, NEmpty } from 'naive-ui'
import type { Novel } from '~/types/novel'

const route = useRoute()
const rankingType = computed(() => route.params.type as string)
const { novels, loading, fetchRanking } = useRanking()
const period = ref('weekly')

useHead({ title: computed(() => `排行榜 — Palimpsest`) })

const rankingTypes = [
  { key: 'views', label: '人氣榜' },
  { key: 'favorites', label: '收藏榜' },
  { key: 'rating', label: '評分榜' },
  { key: 'latest', label: '更新榜' },
  { key: 'completed', label: '完結榜' },
]

function formatMetric(novel: Novel): string {
  switch (rankingType.value) {
    case 'views': return `${(novel.view_count / 10000).toFixed(1)}萬`
    case 'favorites': return `${novel.favorite_count}收藏`
    case 'rating': return `${novel.avg_rating?.toFixed(1)}分`
    default: return ''
  }
}

function loadRanking() {
  fetchRanking(rankingType.value, period.value)
}

watch(rankingType, () => loadRanking())
onMounted(() => loadRanking())
</script>
