<template>
  <div class="space-y-4">
    <div class="flex items-center gap-3 flex-wrap">
      <NuxtLink
        v-for="cat in categories"
        :key="cat.id"
        :to="`/category/${cat.slug}`"
        class="no-underline"
      >
        <n-tag
          :type="cat.slug === activeTop?.slug ? 'primary' : 'default'"
          round
          :bordered="cat.slug !== activeTop?.slug"
          class="cursor-pointer"
        >
          {{ cat.name }}
        </n-tag>
      </NuxtLink>
    </div>

    <div v-if="activeTop?.children?.length" class="flex items-center gap-2 flex-wrap text-sm">
      <span class="text-gray-500">{{ $t('category.subcategories') }}</span>
      <NuxtLink :to="`/category/${activeTop.slug}`" class="no-underline">
        <n-tag size="small" :type="slug === activeTop.slug ? 'primary' : 'default'" class="cursor-pointer">{{ $t('common.all') }}</n-tag>
      </NuxtLink>
      <NuxtLink v-for="child in activeTop.children" :key="child.id" :to="`/category/${child.slug}`" class="no-underline">
        <n-tag size="small" :type="slug === child.slug ? 'primary' : 'default'" class="cursor-pointer">{{ child.name }}</n-tag>
      </NuxtLink>
    </div>

    <div class="flex items-center gap-3">
      <n-select v-model:value="sortBy" :options="sortOptions" size="small" class="w-32" />
      <n-select v-model:value="statusFilter" :options="statusOptions" size="small" class="w-32" />
    </div>

    <n-spin :show="loading">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <NovelCard v-for="novel in novels" :key="novel.id" :novel="novel" />
      </div>
      <n-empty v-if="!loading && novels.length === 0" :description="$t('category.noNovels')" />
    </n-spin>

    <div v-if="pagination.total_pages > 1" class="flex justify-center mt-6">
      <n-pagination
        :page="pagination.page"
        :page-count="pagination.total_pages"
        @update:page="loadNovels"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NTag, NSelect, NPagination, NEmpty } from 'naive-ui'

const { t } = useI18n()
const route = useRoute()
const slug = computed(() => route.params.slug as string)
const { categories } = useCategories()
const { novels, pagination, loading, fetchNovels } = useNovelList()

const sortBy = ref<NovelSort>('latest')
const statusFilter = ref<'all' | 'ongoing' | 'completed' | 'hiatus'>('all')

/** The top-level category for the current slug (itself or its parent). */
const activeTop = computed(() =>
  categories.value.find(c => c.slug === slug.value || c.children?.some(ch => ch.slug === slug.value)),
)
const activeName = computed(() => {
  const top = activeTop.value
  if (!top) return t('category.title')
  return top.slug === slug.value ? top.name : top.children?.find(c => c.slug === slug.value)?.name ?? top.name
})
useHead({ title: () => activeName.value })

const sortOptions = computed(() => NOVEL_SORT_OPTIONS.map(o => ({ label: t(o.labelKey), value: o.value })))
const statusOptions = computed(() => [
  { label: t('category.allStatuses'), value: 'all' },
  ...(['ongoing', 'completed', 'hiatus'] as const).map(value => ({ label: t(`novel.status.${value}`), value })),
])

function loadNovels(page = 1) {
  fetchNovels({
    category: slug.value,
    sort_by: sortBy.value,
    status: statusFilter.value === 'all' ? undefined : statusFilter.value,
    page,
  })
}

watch([slug, sortBy, statusFilter], () => loadNovels(), { immediate: true })
</script>
