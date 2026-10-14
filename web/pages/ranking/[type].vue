<template>
  <div class="space-y-4">
    <div class="flex items-center gap-3 flex-wrap">
      <NuxtLink
        v-for="rt in RANKING_TYPES"
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

    <!-- Only the popularity board is computed per period; the others are all-time. -->
    <n-tabs v-if="rankingType === 'views'" :value="period" type="segment" @update:value="changePeriod">
      <n-tab-pane name="daily" tab="日榜" />
      <n-tab-pane name="weekly" tab="週榜" />
      <n-tab-pane name="monthly" tab="月榜" />
      <n-tab-pane name="all" tab="總榜" />
    </n-tabs>

    <n-alert v-if="!validType" type="warning">找不到這個排行榜。</n-alert>

    <n-spin :show="loading">
      <div class="space-y-3">
        <div
          v-for="(novel, idx) in novels"
          :key="novel.id"
          class="flex items-center gap-4 cursor-pointer hover:bg-gray-50 p-3 rounded"
          data-testid="ranking-item"
          @click="navigateTo(`/novel/${novel.id}`)"
        >
          <span
            class="w-8 h-8 flex items-center justify-center rounded-full text-sm font-bold flex-shrink-0"
            :class="rankOf(idx) <= 3 ? 'bg-primary text-white' : 'bg-gray-100 text-gray-500'"
          >
            {{ rankOf(idx) }}
          </span>
          <NovelCover :src="novel.cover_url" :alt="novel.title" :width="40" :height="56" />
          <div class="flex-1 min-w-0">
            <div class="font-semibold truncate">{{ novel.title }}</div>
            <div class="text-sm text-gray-500">{{ novel.author_name }}</div>
          </div>
          <div class="text-sm text-gray-400 flex-shrink-0">
            {{ formatMetric(novel) }}
          </div>
        </div>
      </div>
      <n-empty v-if="!loading && validType && novels.length === 0" description="暫無排行數據" />
    </n-spin>

    <div v-if="pagination.total_pages > 1" class="flex justify-center">
      <n-pagination :page="pagination.page" :page-count="pagination.total_pages" @update:page="changePage" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NTag, NTabs, NTabPane, NEmpty, NPagination, NAlert } from 'naive-ui'
import type { Novel } from '~/types/novel'
import { formatViewCount, formatRelativeTime } from '~/utils/format'

const PAGE_SIZE = 20
const route = useRoute()
const router = useRouter()
const rankingType = computed(() => route.params.type as RankingType)
const validType = computed(() => RANKING_TYPES.some(t => t.key === rankingType.value))
const period = computed<RankingPeriod>(() => {
  const p = route.query.period as string
  return (['daily', 'weekly', 'monthly', 'all'] as const).includes(p as RankingPeriod) ? p as RankingPeriod : 'weekly'
})
const page = computed(() => Math.max(1, Number(route.query.page) || 1))
const { novels, pagination, loading, fetchRanking } = useRanking()

const title = computed(() => RANKING_TYPES.find(t => t.key === rankingType.value)?.label ?? '排行榜')
useHead({ title: computed(() => `${title.value} — Palimpsest`) })

function rankOf(idx: number) {
  return (pagination.value.page - 1) * pagination.value.page_size + idx + 1
}

function formatMetric(novel: Novel): string {
  switch (rankingType.value) {
    case 'views': return `${formatViewCount(novel.view_count ?? 0)} 次閱讀`
    case 'favorites': return `${novel.favorite_count ?? 0} 收藏`
    case 'rating': return `${(novel.avg_rating ?? 0).toFixed(1)} 分`
    case 'latest': return novel.latest_chapter_at ? formatRelativeTime(novel.latest_chapter_at) : ''
    case 'completed': return `${novel.total_chapters ?? 0} 章`
    default: return ''
  }
}

function changePeriod(value: string) {
  router.push({ query: { ...route.query, period: value, page: undefined } })
}

function changePage(value: number) {
  router.push({ query: { ...route.query, page: value > 1 ? value : undefined } })
}

function load() {
  if (!validType.value) {
    novels.value = []
    return
  }
  fetchRanking(rankingType.value, rankingType.value === 'views' ? period.value : 'all', page.value, PAGE_SIZE)
}

watch([rankingType, period, page], load)
onMounted(load)
</script>
