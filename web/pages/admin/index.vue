<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">{{ $t('admin.menu.dashboard') }}</h1>
      <n-button size="small" :loading="loading" @click="load">{{ $t('admin.refresh') }}</n-button>
    </div>

    <n-spin :show="loading">
      <div v-if="stats" class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4" data-testid="admin-stats">
        <n-card v-for="item in CARDS" :key="item.key" size="small">
          <n-statistic :label="$t(`admin.dashboard.stats.${item.key}`)" :value="stats[item.key]" />
          <NuxtLink v-if="item.to" :to="item.to" class="text-xs text-primary">{{ $t('admin.dashboard.handle') }}</NuxtLink>
        </n-card>
      </div>
      <n-empty v-else-if="!loading" :description="$t('admin.dashboard.loadFailed')" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NButton, NCard, NEmpty, NSpin, NStatistic, useMessage } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'
import type { ApiAdminStats } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })

const { t } = useI18n()
useHead({ title: () => t('header.user.admin') })

const message = useMessage()
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
]

async function load() {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiAdminStats>>('/admin/stats')
    stats.value = res.data
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('admin.dashboard.loadFailed')))
  }
  finally {
    loading.value = false
  }
}

onMounted(load)
</script>
