<template>
  <div class="max-w-3xl mx-auto space-y-6">
    <n-card>
      <div class="flex items-center gap-6">
        <n-avatar :src="user?.avatar_url || undefined" :size="80" round>
          <template v-if="!user?.avatar_url">{{ initial }}</template>
        </n-avatar>
        <div class="flex-1 min-w-0">
          <h2 class="text-xl font-bold" data-testid="profile-nickname">{{ user?.nickname || user?.username }}</h2>
          <div class="text-gray-500">@{{ user?.username }}</div>
          <div class="text-sm text-gray-400 mt-1 whitespace-pre-wrap">{{ user?.bio || $t('profile.noBio') }}</div>
        </div>
        <n-button @click="navigateTo('/profile/settings')">{{ $t('profile.editProfile') }}</n-button>
      </div>
    </n-card>

    <n-spin :show="loadingStats">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <n-card v-for="item in totals" :key="item.label" class="text-center" size="small">
          <div class="text-2xl font-bold text-primary">{{ item.value }}</div>
          <div class="text-sm text-gray-500 mt-1">{{ item.label }}</div>
        </n-card>
      </div>
    </n-spin>

    <n-card :title="$t('profile.stats.title')">
      <template #header-extra>
        <n-radio-group v-model:value="period" size="small">
          <n-radio-button value="daily">{{ $t('profile.stats.last7Days') }}</n-radio-button>
          <n-radio-button value="weekly">{{ $t('profile.stats.last8Weeks') }}</n-radio-button>
          <n-radio-button value="monthly">{{ $t('profile.stats.last12Months') }}</n-radio-button>
        </n-radio-group>
      </template>
      <div v-if="stats?.buckets?.length" data-testid="reading-chart">
        <div class="flex items-end gap-2 h-40 border-b border-gray-200">
          <div
            v-for="bucket in stats.buckets"
            :key="bucket.start"
            class="flex-1 flex flex-col items-center justify-end h-full"
            :title="$t('profile.stats.barTitle', { period: bucketLabel(bucket.start), chapters: $t('ranking.metrics.chapters', { n: bucket.chapters }, bucket.chapters), words: formatWordCount(bucket.words), time: formatDuration(bucket.seconds) })"
          >
            <span class="text-xs text-gray-400 mb-1">{{ bucket.chapters || '' }}</span>
            <div class="w-full max-w-10 bg-blue-400 rounded-t" :style="{ height: `${barHeight(bucket.words)}%` }" />
          </div>
        </div>
        <div class="flex gap-2 mt-1">
          <div v-for="bucket in stats.buckets" :key="bucket.start" class="flex-1 text-center text-xs text-gray-400 truncate">
            {{ bucketLabel(bucket.start) }}
          </div>
        </div>
        <div class="text-xs text-gray-400 mt-2">{{ $t('profile.stats.legend') }}</div>
        <n-table size="small" class="mt-4" :single-line="false">
          <thead>
            <tr><th>{{ $t('profile.stats.period') }}</th><th>{{ $t('profile.stats.chapters') }}</th><th>{{ $t('profile.stats.words') }}</th><th>{{ $t('profile.stats.time') }}</th></tr>
          </thead>
          <tbody>
            <tr v-for="bucket in [...stats.buckets].reverse()" :key="bucket.start">
              <td>{{ bucketLabel(bucket.start) }}</td>
              <td>{{ bucket.chapters }}</td>
              <td>{{ formatWordCount(bucket.words) }}</td>
              <td>{{ formatDuration(bucket.seconds) }}</td>
            </tr>
          </tbody>
        </n-table>
      </div>
      <n-empty v-else-if="!loadingStats" :description="$t('profile.stats.empty')" />
    </n-card>

    <n-card>
      <div class="divide-y">
        <NuxtLink to="/profile/history" class="flex items-center justify-between py-3">
          <span>{{ $t('header.user.history') }}</span><span class="text-gray-400">›</span>
        </NuxtLink>
        <NuxtLink to="/profile/bookmarks" class="flex items-center justify-between py-3">
          <span>{{ $t('header.user.bookmarks') }}</span><span class="text-gray-400">›</span>
        </NuxtLink>
        <NuxtLink to="/bookshelf" class="flex items-center justify-between py-3">
          <span>{{ $t('header.user.bookshelf') }}</span><span class="text-gray-400">›</span>
        </NuxtLink>
        <NuxtLink to="/profile/settings" class="flex items-center justify-between py-3">
          <span>{{ $t('profile.accountAndReading') }}</span><span class="text-gray-400">›</span>
        </NuxtLink>
      </div>
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { NCard, NAvatar, NButton, NSpin, NRadioGroup, NRadioButton, NTable, NEmpty, useMessage } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'
import type { ApiReadingStats } from '~/types/models'

definePageMeta({ middleware: 'auth' })

const { t, formatDuration, formatWordCount, formatNumber } = useFormat()
useHead({ title: () => t('header.user.profile') })

const authStore = useAuthStore()
const message = useMessage()
const user = computed(() => authStore.user)
const initial = computed(() => (user.value?.nickname || user.value?.username || '?').slice(0, 1))

const period = ref<'daily' | 'weekly' | 'monthly'>('daily')
const stats = ref<ApiReadingStats | null>(null)
const loadingStats = ref(false)

const totals = computed(() => {
  const s = stats.value
  return [
    { label: t('profile.totals.words'), value: formatWordCount(s?.total_read_words ?? user.value?.total_read_words ?? 0) },
    { label: t('profile.totals.time'), value: formatDuration(s?.total_read_seconds ?? user.value?.total_read_seconds ?? 0) },
    { label: t('profile.totals.chapters'), value: formatNumber(s?.chapters_read ?? 0) },
    { label: t('profile.totals.novels'), value: formatNumber(s?.novels_read ?? 0) },
    { label: t('profile.totals.bookshelf'), value: formatNumber(s?.bookshelf_count ?? 0) },
    { label: t('profile.totals.bookmarks'), value: formatNumber(s?.bookmark_count ?? 0) },
    { label: t('profile.totals.reviews'), value: formatNumber(s?.review_count ?? 0) },
  ]
})

const maxWords = computed(() => Math.max(1, ...(stats.value?.buckets ?? []).map(b => b.words)))

function barHeight(words: number) {
  return words > 0 ? Math.max(4, Math.round(words / maxWords.value * 100)) : 0
}

function bucketLabel(start: string) {
  const d = new Date(start)
  if (Number.isNaN(d.getTime())) return start
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  const dd = String(d.getDate()).padStart(2, '0')
  if (period.value === 'monthly') return `${d.getFullYear()}/${mm}`
  if (period.value === 'weekly') return t('profile.stats.weekOf', { date: `${mm}/${dd}` })
  return `${mm}/${dd}`
}

async function loadStats() {
  loadingStats.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiReadingStats>>('/users/me/reading-stats', { params: { period: period.value } })
    stats.value = res.data
  }
  catch (e) {
    message.error(describeError(t, e, {}, t('profile.stats.loadFailed')))
  }
  finally {
    loadingStats.value = false
  }
}

watch(period, loadStats)
onMounted(() => {
  void authStore.fetchMe()
  void loadStats()
})
</script>
