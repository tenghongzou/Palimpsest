<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">{{ $t('novel.chapterList') }}</h1>
      <n-button text @click="sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'">
        {{ sortOrder === 'asc' ? $t('novel.sortAsc') : $t('novel.sortDesc') }}
      </n-button>
    </div>
    <n-spin :show="loading">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
        <NuxtLink
          v-for="ch in sortedChapters"
          :key="ch.id"
          :to="`/read/${ch.id}`"
          class="px-4 py-3 rounded border hover:bg-gray-50 flex items-center justify-between"
        >
          <span class="truncate">{{ chapterLabel(ch.chapter_number, ch.title) }}</span>
          <span class="text-xs text-gray-400 flex-shrink-0 ml-2">{{ formatWordCount(ch.word_count ?? 0) }}</span>
        </NuxtLink>
      </div>
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NButton } from 'naive-ui'

const { t, chapterLabel, formatWordCount } = useFormat()
useHead({ title: () => t('novel.chapterList') })
const route = useRoute()
const novelId = route.params.id as string
const { chapters, loading } = useNovel(novelId)
const sortOrder = ref<'asc' | 'desc'>('asc')

const sortedChapters = computed(() => {
  const list = [...chapters.value]
  return sortOrder.value === 'desc' ? list.reverse() : list
})
</script>
