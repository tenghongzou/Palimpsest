<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">總覽</h1>
      <n-button size="small" :loading="loading" @click="load">重新整理</n-button>
    </div>

    <n-spin :show="loading">
      <div v-if="stats" class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4" data-testid="admin-stats">
        <n-card v-for="item in cards" :key="item.key" size="small">
          <n-statistic :label="item.label" :value="stats[item.key]" />
          <NuxtLink v-if="item.to" :to="item.to" class="text-xs text-primary">前往處理</NuxtLink>
        </n-card>
      </div>
      <n-empty v-else-if="!loading" description="無法載入統計資料" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NButton, NCard, NEmpty, NSpin, NStatistic, useMessage } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'
import type { ApiAdminStats } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })
useHead({ title: '管理後台 — Palimpsest' })

const message = useMessage()
const stats = ref<ApiAdminStats | null>(null)
const loading = ref(false)

const cards: { key: keyof ApiAdminStats, label: string, to?: string }[] = [
  { key: 'users', label: '用戶總數' },
  { key: 'new_users_today', label: '今日新用戶' },
  { key: 'active_readers_7d', label: '7 日活躍讀者' },
  { key: 'reads_today', label: '今日閱讀章節' },
  { key: 'novels', label: '小說總數' },
  { key: 'published_novels', label: '已上架小說' },
  { key: 'chapters', label: '章節總數' },
  { key: 'reviews', label: '書評數' },
  { key: 'comments', label: '留言數' },
  { key: 'pending_reports', label: '待處理檢舉', to: '/admin/reports' },
]

async function load() {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiAdminStats>>('/admin/stats')
    stats.value = res.data
  }
  catch (error) {
    message.error(describeError(error, {}, '無法載入統計資料'))
  }
  finally {
    loading.value = false
  }
}

onMounted(load)
</script>
