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
          <div class="text-sm text-gray-400 mt-1 whitespace-pre-wrap">{{ user?.bio || '這個人很懶，什麼都沒寫' }}</div>
        </div>
        <n-button @click="navigateTo('/profile/settings')">編輯資料</n-button>
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

    <n-card title="閱讀統計">
      <template #header-extra>
        <n-radio-group v-model:value="period" size="small">
          <n-radio-button value="daily">近 7 天</n-radio-button>
          <n-radio-button value="weekly">近 8 週</n-radio-button>
          <n-radio-button value="monthly">近 12 個月</n-radio-button>
        </n-radio-group>
      </template>
      <div v-if="stats?.buckets?.length" data-testid="reading-chart">
        <div class="flex items-end gap-2 h-40 border-b border-gray-200">
          <div
            v-for="bucket in stats.buckets"
            :key="bucket.start"
            class="flex-1 flex flex-col items-center justify-end h-full"
            :title="`${bucketLabel(bucket.start)}：${bucket.chapters} 章、${formatWordCount(bucket.words)}、${formatDuration(bucket.seconds)}`"
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
        <div class="text-xs text-gray-400 mt-2">長條高度為閱讀字數，上方數字為閱讀章數。</div>
        <n-table size="small" class="mt-4" :single-line="false">
          <thead>
            <tr><th>期間</th><th>章數</th><th>字數</th><th>時間</th></tr>
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
      <n-empty v-else-if="!loadingStats" description="還沒有閱讀紀錄" />
    </n-card>

    <n-card>
      <div class="divide-y">
        <NuxtLink to="/profile/history" class="flex items-center justify-between py-3">
          <span>閱讀紀錄</span><span class="text-gray-400">›</span>
        </NuxtLink>
        <NuxtLink to="/profile/bookmarks" class="flex items-center justify-between py-3">
          <span>我的書籤</span><span class="text-gray-400">›</span>
        </NuxtLink>
        <NuxtLink to="/bookshelf" class="flex items-center justify-between py-3">
          <span>我的書架</span><span class="text-gray-400">›</span>
        </NuxtLink>
        <NuxtLink to="/profile/settings" class="flex items-center justify-between py-3">
          <span>帳號與閱讀設定</span><span class="text-gray-400">›</span>
        </NuxtLink>
      </div>
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { NCard, NAvatar, NButton, NSpin, NRadioGroup, NRadioButton, NTable, NEmpty, useMessage } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'
import type { ApiReadingStats } from '~/types/models'
import { formatDuration, formatWordCount } from '~/utils/format'

definePageMeta({ middleware: 'auth' })
useHead({ title: '個人中心 — Palimpsest' })

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
    { label: '累計閱讀', value: formatWordCount(s?.total_read_words ?? user.value?.total_read_words ?? 0) },
    { label: '閱讀時間', value: formatDuration(s?.total_read_seconds ?? user.value?.total_read_seconds ?? 0) },
    { label: '讀過章節', value: s?.chapters_read ?? 0 },
    { label: '讀過小說', value: s?.novels_read ?? 0 },
    { label: '書架藏書', value: s?.bookshelf_count ?? 0 },
    { label: '書籤', value: s?.bookmark_count ?? 0 },
    { label: '書評', value: s?.review_count ?? 0 },
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
  if (period.value === 'weekly') return `${mm}/${dd} 起`
  return `${mm}/${dd}`
}

async function loadStats() {
  loadingStats.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiReadingStats>>('/users/me/reading-stats', { params: { period: period.value } })
    stats.value = res.data
  }
  catch (e) {
    message.error(describeError(e, {}, '無法載入閱讀統計'))
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
