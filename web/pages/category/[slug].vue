<template>
  <div class="space-y-4">
    <div class="flex items-center gap-4 flex-wrap">
      <NuxtLink
        v-for="cat in categories"
        :key="cat.id"
        :to="`/category/${cat.slug}`"
        class="no-underline"
      >
        <n-tag
          :type="cat.slug === slug ? 'primary' : 'default'"
          round
          :bordered="cat.slug !== slug"
          class="cursor-pointer"
        >
          {{ cat.name }}
        </n-tag>
      </NuxtLink>
    </div>

    <div class="flex items-center gap-3">
      <n-select
        v-model:value="sortBy"
        :options="sortOptions"
        size="small"
        class="w-32"
      />
      <n-select
        v-model:value="statusFilter"
        :options="statusOptions"
        size="small"
        class="w-32"
      />
    </div>

    <n-spin :show="loading">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <NovelCard v-for="novel in novels" :key="novel.id" :novel="novel" />
      </div>
      <n-empty v-if="!loading && novels.length === 0" description="暫無小說" />
    </n-spin>

    <div v-if="pagination.total_pages > 1" class="flex justify-center mt-6">
      <n-pagination
        :page="pagination.page"
        :page-count="pagination.total_pages"
        @update:page="handlePageChange"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NTag, NSelect, NPagination, NEmpty } from 'naive-ui'

const route = useRoute()
const slug = computed(() => route.params.slug as string)
const { categories } = useCategories()
const { novels, pagination, loading, fetchNovels } = useNovelList()

const sortBy = ref('latest')
const statusFilter = ref('all')

const sortOptions = [
  { label: '最新', value: 'latest' },
  { label: '人氣', value: 'views' },
  { label: '評分', value: 'rating' },
  { label: '字數', value: 'words' },
]

const statusOptions = [
  { label: '全部', value: 'all' },
  { label: '連載中', value: 'ongoing' },
  { label: '已完結', value: 'completed' },
]

function loadNovels(page = 1) {
  const params: Record<string, any> = {
    category: slug.value,
    sort: sortBy.value,
    page,
  }
  if (statusFilter.value !== 'all') params.status = statusFilter.value
  fetchNovels(params)
}

function handlePageChange(page: number) {
  loadNovels(page)
}

watch([slug, sortBy, statusFilter], () => loadNovels(), { immediate: true })
</script>
