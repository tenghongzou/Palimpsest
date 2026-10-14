<template>
  <div class="max-w-3xl mx-auto space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">{{ $t('header.user.history') }}</h1>
      <n-button text @click="navigateTo('/profile')">{{ $t('profile.backToProfile') }}</n-button>
    </div>

    <n-spin :show="loading">
      <div class="space-y-3">
        <n-card v-for="item in items" :key="item.id" size="small" data-testid="history-item">
          <div class="flex gap-3 items-center">
            <NovelCover :src="item.novel?.cover_url" :alt="item.novel?.title" :width="48" :height="66" />
            <div class="flex-1 min-w-0">
              <NuxtLink :to="`/novel/${item.novel_id}`" class="font-semibold truncate block">
                {{ item.novel?.title || $t('profile.history.removedNovel') }}
              </NuxtLink>
              <div class="text-sm text-gray-500 truncate">
                <template v-if="item.chapter">{{ chapterLabel(item.chapter.chapter_number, item.chapter.title) }}</template>
              </div>
              <div class="text-xs text-gray-400">
                {{ formatDateTime(item.read_at) }}
                <span v-if="item.duration"> · {{ $t('profile.history.readFor', { time: formatDuration(item.duration) }) }}</span>
              </div>
            </div>
            <n-button size="small" type="primary" secondary @click="navigateTo(`/read/${item.chapter_id}`)">
              {{ $t('novel.continueReading') }}
            </n-button>
          </div>
        </n-card>
      </div>
      <n-empty v-if="!loading && items.length === 0" :description="$t('profile.stats.empty')" class="py-12" />
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

definePageMeta({ middleware: 'auth' })

const { t, formatDateTime, formatDuration, chapterLabel } = useFormat()
useHead({ title: () => t('header.user.history') })

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
    message.error(describeError(t, e, {}, t('profile.history.loadFailed')))
  }
  finally {
    loading.value = false
  }
}

onMounted(() => load())
</script>
