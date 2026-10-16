<template>
  <div class="admin-dashboard space-y-6">
    <div class="flex items-center justify-between gap-3">
      <h1 class="text-xl font-bold">{{ $t('admin.menu.dashboard') }}</h1>
      <n-button size="small" :loading="loading" @click="loadAll">{{ $t('admin.refresh') }}</n-button>
    </div>

    <n-spin :show="loading">
      <div v-if="stats" class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-4" data-testid="admin-stats">
        <n-card v-for="item in CARDS" :key="item.key" size="small">
          <n-statistic :label="$t(`admin.dashboard.stats.${item.key}`)" :value="stats[item.key]" />
          <NuxtLink v-if="item.to" :to="item.to" class="text-xs text-primary">{{ $t('admin.dashboard.handle') }}</NuxtLink>
        </n-card>
      </div>
      <n-empty v-else-if="!loading" :description="$t('admin.dashboard.loadFailed')" />
    </n-spin>

    <n-card :title="$t('admin.dashboard.trends.title')" data-testid="admin-trends">
      <template #header-extra>
        <n-radio-group v-model:value="range" size="small" data-testid="trend-range">
          <n-radio-button v-for="n in TREND_RANGES" :key="n" :value="n">{{ rangeLabel(n) }}</n-radio-button>
        </n-radio-group>
      </template>
      <n-spin :show="trends.loading.value">
        <div v-if="trends.failed.value" class="py-8">
          <n-empty :description="$t('admin.dashboard.trends.loadFailed')">
            <template #extra><n-button size="small" @click="trends.run()">{{ $t('common.retry') }}</n-button></template>
          </n-empty>
        </div>
        <div v-else-if="trendDays.length && !quiet" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-5">
            <div v-for="key in ACTIVITY_SERIES" :key="key" :data-testid="`trend-${key}`">
              <div class="flex items-baseline justify-between gap-2 mb-1">
                <span class="text-sm font-medium">{{ $t(`admin.dashboard.series.${key}`) }}</span>
                <span class="text-xs text-gray-500">{{ seriesSummary(key) }}</span>
              </div>
              <AdminChart
                :labels="dayLabels"
                :tooltip-titles="dayTitles"
                :series="[{ key, label: $t(`admin.dashboard.series.${key}`), color: SERIES_COLORS[key], values: seriesValues(trendDays, key) }]"
                :integer="key !== 'reading_hours'"
                :format-value="key === 'reading_hours' ? formatHours : formatCount"
                :height="150"
                :aria-label="$t(`admin.dashboard.series.${key}`)"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div class="lg:col-span-2" data-testid="trend-engagement">
              <div class="flex flex-wrap items-center justify-between gap-2 mb-1">
                <span class="text-sm font-medium">{{ $t('admin.dashboard.trends.engagement') }}</span>
                <n-checkbox-group v-model:value="visibleEngagement" size="small">
                  <n-checkbox v-for="key in ENGAGEMENT_SERIES" :key="key" :value="key">
                    <span class="inline-flex items-center gap-1 text-xs">
                      <span class="inline-block w-2 h-2 rounded-sm" :style="{ background: ENGAGEMENT_COLORS[key] }" />
                      {{ $t(`admin.dashboard.series.${key}`) }} ({{ formatCount(seriesTotal(trendDays, key)) }})
                    </span>
                  </n-checkbox>
                </n-checkbox-group>
              </div>
              <AdminChart
                type="bar"
                :labels="dayLabels"
                :tooltip-titles="dayTitles"
                :series="engagementSeries"
                :format-value="formatCount"
                :height="180"
                :aria-label="$t('admin.dashboard.trends.engagement')"
              />
            </div>
            <n-card size="small" embedded data-testid="returning-rate">
              <div class="flex items-center gap-1 text-sm text-gray-500">
                {{ $t('admin.dashboard.trends.returningRate') }}
                <n-tooltip trigger="hover" :style="{ maxWidth: '260px' }">
                  <template #trigger>
                    <n-icon :size="16" class="cursor-help" :aria-label="$t('admin.dashboard.trends.returningRateHelp')"><InformationCircleOutline /></n-icon>
                  </template>
                  {{ $t('admin.dashboard.trends.returningRateHelp') }}
                </n-tooltip>
              </div>
              <div class="text-3xl font-bold text-primary mt-1">{{ formatPercent(trends.data.value?.returning_rate, intl) }}</div>
              <n-progress
                type="line"
                :percentage="Math.round((trends.data.value?.returning_rate ?? 0) * 100)"
                :show-indicator="false"
                :height="6"
                class="mt-2"
              />
              <p class="text-xs text-gray-500 mt-3 leading-relaxed">{{ $t('admin.dashboard.trends.returningRateHelp') }}</p>
            </n-card>
          </div>
        </div>
        <n-empty v-else-if="!trends.loading.value" class="py-8" :description="$t('admin.dashboard.trends.empty')" />
      </n-spin>
    </n-card>

    <div class="grid grid-cols-1 xl:grid-cols-5 gap-6">
      <n-card :title="$t('admin.dashboard.topNovels.title')" class="xl:col-span-3" data-testid="admin-top-novels">
        <template #header-extra>
          <n-radio-group v-model:value="topRange" size="small">
            <n-radio-button v-for="n in TOP_NOVEL_RANGES" :key="n" :value="n">{{ rangeLabel(n) }}</n-radio-button>
          </n-radio-group>
        </template>
        <div v-if="topNovels.failed.value" class="py-6">
          <n-empty :description="$t('admin.dashboard.topNovels.loadFailed')">
            <template #extra><n-button size="small" @click="topNovels.run()">{{ $t('common.retry') }}</n-button></template>
          </n-empty>
        </div>
        <n-data-table
          v-else
          size="small"
          :columns="topColumns"
          :data="topNovels.data.value ?? []"
          :loading="topNovels.loading.value"
          :row-key="(row: ApiAdminTopNovel) => row.novel.id"
          :scroll-x="560"
        >
          <template #empty>
            <n-empty :description="$t('admin.dashboard.topNovels.empty')" />
          </template>
        </n-data-table>
      </n-card>

      <n-card :title="$t('admin.dashboard.categories.title')" class="xl:col-span-2" data-testid="admin-categories">
        <template #header-extra>
          <span class="text-xs text-gray-500">{{ rangeLabel(range) }}</span>
        </template>
        <n-spin :show="categories.loading.value">
          <div v-if="categories.failed.value" class="py-6">
            <n-empty :description="$t('admin.dashboard.categories.loadFailed')">
              <template #extra><n-button size="small" @click="categories.run()">{{ $t('common.retry') }}</n-button></template>
            </n-empty>
          </div>
          <div v-else-if="categoryRows.length" class="space-y-2.5">
            <div v-for="row in categoryRows" :key="row.category.id" class="text-sm" :data-testid="`category-${row.category.slug}`">
              <div class="flex items-baseline justify-between gap-2">
                <span class="truncate">{{ row.category.name }}</span>
                <span class="text-xs text-gray-500 whitespace-nowrap">{{ $t('admin.dashboard.categories.value', { reads: formatCount(row.reads), readers: formatCount(row.readers) }) }}</span>
              </div>
              <div class="h-2 mt-1 rounded bg-gray-500/10 overflow-hidden">
                <div class="h-full rounded bg-primary" :style="{ width: `${row.width}%` }" />
              </div>
            </div>
            <p class="text-xs text-gray-500 pt-1">{{ $t('admin.dashboard.categories.note') }}</p>
          </div>
          <n-empty v-else-if="!categories.loading.value" class="py-6" :description="$t('admin.dashboard.categories.empty')" />
        </n-spin>
      </n-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  NButton, NCard, NCheckbox, NCheckboxGroup, NDataTable, NEmpty, NIcon, NProgress, NRadioButton, NRadioGroup,
  NSpin, NStatistic, NTooltip, useMessage,
} from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { InformationCircleOutline } from '@vicons/ionicons5'
import { h } from 'vue'
import type { ApiResponse } from '~/utils/api'
import type { ApiAdminCategoryStat, ApiAdminStats, ApiAdminTopNovel, ApiAdminTrends } from '~/types/models'
import { intlLocale } from '~/i18n/constants'
import {
  ACTIVITY_SERIES, ENGAGEMENT_SERIES, SERIES_COLORS, TOP_NOVEL_RANGES, TREND_RANGES, formatPercent, isQuietPeriod,
  seriesTotal, seriesValues, shareWidths, shortDate, utcOffsetMinutes,
  type TopNovelRange, type TrendRange, type TrendSeriesKey,
} from '~/utils/adminStats'
import NovelCover from '~/components/novel/NovelCover.vue'

definePageMeta({ middleware: 'admin', layout: 'admin' })

const { t, locale } = useI18n()
useHead({ title: () => t('header.user.admin') })

const message = useMessage()
const pending = usePendingModeration()
const intl = computed(() => intlLocale(locale.value))

const stats = ref<ApiAdminStats | null>(null)
const loading = ref(false)

const CARDS: { key: keyof ApiAdminStats, to?: string }[] = [
  { key: 'users' },
  { key: 'new_users_today' },
  { key: 'active_readers_7d' },
  { key: 'reads_today' },
  { key: 'novels' },
  { key: 'published_novels' },
  { key: 'chapters' },
  { key: 'reviews' },
  { key: 'comments' },
  { key: 'pending_reports', to: '/admin/reports' },
  { key: 'pending_moderation', to: '/admin/moderation' },
]

async function loadStats() {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiAdminStats>>('/admin/stats', { params: { utc_offset: utcOffsetMinutes() } })
    stats.value = res.data
    pending.set(res.data.pending_moderation)
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('admin.dashboard.loadFailed')))
  }
  finally {
    loading.value = false
  }
}

// ---- Trends
const range = ref<TrendRange>(30)
const trends = useAdminSection(async () => {
  const res = await apiFetch<ApiResponse<ApiAdminTrends>>('/admin/stats/trends', { params: { days: range.value, utc_offset: utcOffsetMinutes() } })
  return res.data
})
const trendDays = computed(() => trends.data.value?.days ?? [])
const quiet = computed(() => isQuietPeriod(trendDays.value))
const dayLabels = computed(() => trendDays.value.map(d => shortDate(d.date)))
const dayTitles = computed(() => trendDays.value.map(d => longDate(d.date)))

/** A local calendar day ("YYYY-MM-DD") with its weekday, in the UI language. */
function longDate(date: string) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(date)
  if (!m) return date
  return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
    .toLocaleDateString(intl.value, { year: 'numeric', month: 'short', day: 'numeric', weekday: 'short' })
}

function formatCount(value: number) {
  return value.toLocaleString(intl.value)
}

function formatHours(value: number) {
  return t('admin.dashboard.trends.hours', { n: value.toLocaleString(intl.value, { maximumFractionDigits: 1 }) })
}

function rangeLabel(days: number) {
  return days === 1 ? t('admin.dashboard.today') : t('admin.dashboard.lastDays', { n: days })
}

/** Active readers are distinct per day, so they are averaged; the other series are summed. */
function seriesSummary(key: TrendSeriesKey) {
  if (key === 'active_readers') {
    const values = seriesValues(trendDays.value, key)
    const avg = values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : 0
    return t('admin.dashboard.trends.avgPerDay', { value: formatCount(avg) })
  }
  const total = seriesTotal(trendDays.value, key)
  return t('admin.dashboard.trends.total', { value: key === 'reading_hours' ? formatHours(total) : formatCount(total) })
}

// The bar chart has its own palette so the three columns are distinguishable.
const ENGAGEMENT_COLORS: Record<string, string> = {
  new_reviews: SERIES_COLORS.new_reviews,
  new_comments: SERIES_COLORS.new_comments,
  bookshelf_adds: '#13a8a8',
}
const visibleEngagement = ref<string[]>([...ENGAGEMENT_SERIES])
const engagementSeries = computed(() => ENGAGEMENT_SERIES
  .filter(key => visibleEngagement.value.includes(key))
  .map(key => ({ key, label: t(`admin.dashboard.series.${key}`), color: ENGAGEMENT_COLORS[key]!, values: seriesValues(trendDays.value, key) })))

// ---- Top novels
const topRange = ref<TopNovelRange>(7)
const topNovels = useAdminSection(async () => {
  const res = await apiFetch<ApiResponse<ApiAdminTopNovel[]>>('/admin/stats/top-novels', { params: { days: topRange.value, limit: 10, utc_offset: utcOffsetMinutes() } })
  return res.data ?? []
})

const topColumns = computed<DataTableColumns<ApiAdminTopNovel>>(() => [
  { title: '#', key: 'rank', width: 44, render: (_row, index) => index + 1 },
  {
    title: t('admin.dashboard.topNovels.novel'),
    key: 'novel',
    minWidth: 220,
    render: row => h('div', { class: 'flex items-center gap-3' }, [
      h(NovelCover, { src: row.novel.cover_url, alt: row.novel.title, width: 36, height: 48 }),
      h('div', { class: 'min-w-0' }, [
        h(resolveComponent('NuxtLink'), { to: `/admin/novels/${row.novel.id}`, class: 'font-medium text-primary line-clamp-1' }, () => row.novel.title),
        h('div', { class: 'text-xs text-gray-500 truncate' }, row.novel.author_name),
      ]),
    ]),
  },
  { title: t('admin.dashboard.topNovels.reads'), key: 'reads', width: 90, align: 'right', render: row => formatCount(row.reads) },
  { title: t('admin.dashboard.topNovels.readers'), key: 'readers', width: 90, align: 'right', render: row => formatCount(row.readers) },
  { title: t('admin.dashboard.topNovels.bookshelfAdds'), key: 'bookshelf_adds', width: 100, align: 'right', render: row => formatCount(row.bookshelf_adds) },
])

// ---- Categories (same period as the trends)
const categories = useAdminSection(async () => {
  const res = await apiFetch<ApiResponse<ApiAdminCategoryStat[]>>('/admin/stats/categories', { params: { days: range.value, utc_offset: utcOffsetMinutes() } })
  return res.data ?? []
})
const categoryRows = computed(() => {
  const rows = categories.data.value ?? []
  const widths = shareWidths(rows.map(r => r.reads))
  return rows.map((r, i) => ({ ...r, width: widths[i] ?? 0 }))
})

function loadAll() {
  void loadStats()
  void trends.run()
  void topNovels.run()
  void categories.run()
}

watch(range, () => {
  void trends.run()
  void categories.run()
})
watch(topRange, () => topNovels.run())
onMounted(loadAll)
</script>

<style scoped>
/* Range selectors wrap below the card title on narrow screens. */
.admin-dashboard :deep(.n-card-header) {
  flex-wrap: wrap;
  row-gap: 8px;
}
.admin-dashboard :deep(.n-card-header__main) {
  flex: 1 0 auto;
  white-space: nowrap;
}
</style>
