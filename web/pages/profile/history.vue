<template>
  <div class="max-w-3xl mx-auto space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">閱讀紀錄</h1>
      <n-button text @click="navigateTo('/profile')">返回個人中心</n-button>
    </div>

    <n-spin :show="loading">
      <div class="space-y-3">
        <n-card v-for="item in items" :key="item.id" size="small" data-testid="history-item">
          <div class="flex gap-3 items-center">
            <NovelCover :src="item.novel?.cover_url" :alt="item.novel?.title" :width="48" :height="66" />
            <div class="flex-1 min-w-0">
              <NuxtLink :to="`/novel/${item.novel_id}`" class="font-semibold truncate block">
                {{ item.novel?.title || '（已下架的小說）' }}
              </NuxtLink>
              <div class="text-sm text-gray-500 truncate">
                <template v-if="item.chapter">第 {{ item.chapter.chapter_number }} 章 {{ item.chapter.title }}</template>
              </div>
              <div class="text-xs text-gray-400">
                {{ formatDateTime(item.read_at) }}
                <span v-if="item.duration"> · 閱讀 {{ formatDuration(item.duration) }}</span>
              </div>
            </div>
            <n-button size="small" type="primary" secondary @click="navigateTo(`/read/${item.chapter_id}`)">
              繼續閱讀
            </n-button>
          </div>
        </n-card>
      </div>
      <n-empty v-if="!loading && items.length === 0" description="還沒有閱讀紀錄" class="py-12" />
    </n-spin>

    <div v-if="pagination.total_pages > 1" class="flex justify-center">
      <n-pagination :page="pagination.page" :page-count="pagination.total_pages" @update:page="load" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { NCard, NButton, NSpin, NEmpty, NPagination, useMessage } from 'naive-ui'
import type { ApiResponse, Paginated, Pagination } from '~/utils/api'
import type { ApiReadingHistory } from '~/types/models'
import { formatDateTime, formatDuration } from '~/utils/format'

definePageMeta({ middleware: 'auth' })
useHead({ title: '閱讀紀錄 — Palimpsest' })

const message = useMessage()
const items = ref<ApiReadingHistory[]>([])
const pagination = ref<Pagination>({ page: 1, page_size: 20, total: 0, total_pages: 0 })
const loading = ref(false)

async function load(page = 1) {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<Paginated<ApiReadingHistory>>>('/reading-history', { params: { page, page_size: 20 } })
    items.value = res.data.items
    pagination.value = res.data.pagination
  }
  catch (e) {
    message.error(describeError(e, {}, '無法載入閱讀紀錄'))
  }
  finally {
    loading.value = false
  }
}

onMounted(() => load())
</script>
