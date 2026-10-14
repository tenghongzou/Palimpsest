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
          {{ $t(rt.labelKey) }}
        </n-tag>
      </NuxtLink>
    </div>

    <!-- Only the popularity board is computed per period; the others are all-time. -->
    <n-tabs v-if="rankingType === 'views'" :value="period" type="segment" @update:value="changePeriod">
      <n-tab-pane name="daily" :tab="$t('ranking.periods.daily')" />
      <n-tab-pane name="weekly" :tab="$t('ranking.periods.weekly')" />
      <n-tab-pane name="monthly" :tab="$t('ranking.periods.monthly')" />
      <n-tab-pane name="all" :tab="$t('ranking.periods.all')" />
    </n-tabs>

    <n-alert v-if="!validType" type="warning">{{ $t('ranking.notFound') }}</n-alert>

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
      <n-empty v-if="!loading && validType && novels.length === 0" :description="$t('ranking.empty')" />
    </n-spin>

    <div v-if="pagination.total_pages > 1" class="flex justify-center">
      <n-pagination :page="pagination.page" :page-count="pagination.total_pages" @update:page="changePage" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NTag, NTabs, NTabPane, NEmpty, NPagination, NAlert } from 'naive-ui'
import type { Novel } from '~/types/novel'

const PAGE_SIZE = 20
const { t, formatViewCount, formatRelativeTime, formatNumber } = useFormat()
const route = useRoute()
const router = useRouter()
const rankingType = computed(() => route.params.type as RankingType)
const validType = computed(() => RANKING_TYPES.some(r => r.key === rankingType.value))
const period = computed<RankingPeriod>(() => {
  const p = route.query.period as string
  return (['daily', 'weekly', 'monthly', 'all'] as const).includes(p as RankingPeriod) ? p as RankingPeriod : 'weekly'
})
const page = computed(() => Math.max(1, Number(route.query.page) || 1))
const { novels, pagination, loading, fetchRanking } = useRanking()

const title = computed(() => {
  const type = RANKING_TYPES.find(r => r.key === rankingType.value)
  return type ? t(type.labelKey) : t('ranking.title')
})
useHead({ title: () => title.value })

function rankOf(idx: number) {
  return (pagination.value.page - 1) * pagination.value.page_size + idx + 1
}

function formatMetric(novel: Novel): string {
  switch (rankingType.value) {
    case 'views': return t('ranking.metrics.views', { n: formatViewCount(novel.view_count ?? 0) }, novel.view_count ?? 0)
    case 'favorites': return t('ranking.metrics.favorites', { n: formatNumber(novel.favorite_count ?? 0) }, novel.favorite_count ?? 0)
    case 'rating': return t('ranking.metrics.rating', { n: (novel.avg_rating ?? 0).toFixed(1) })
    case 'latest': return novel.latest_chapter_at ? formatRelativeTime(novel.latest_chapter_at) : ''
    case 'completed': return t('ranking.metrics.chapters', { n: novel.total_chapters ?? 0 }, novel.total_chapters ?? 0)
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
