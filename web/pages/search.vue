<template>
  <div class="space-y-6">
    <n-input
      v-model:value="query"
      placeholder="搜尋小說名稱、作者..."
      size="large"
      clearable
      @keyup.enter="handleSearch"
      @input="handleInput"
    >
      <template #prefix>
        <n-icon :component="SearchIcon" />
      </template>
    </n-input>

    <div v-if="suggestions.length > 0 && !hasSearched" class="space-y-2">
      <div
        v-for="s in suggestions"
        :key="s"
        class="px-3 py-2 hover:bg-gray-50 rounded cursor-pointer"
        @click="query = s; handleSearch()"
      >
        {{ s }}
      </div>
    </div>

    <div v-if="!hasSearched && hotKeywords.length > 0">
      <h3 class="text-base font-semibold mb-3">熱門搜尋</h3>
      <div class="flex flex-wrap gap-2">
        <n-tag
          v-for="keyword in hotKeywords"
          :key="keyword"
          round
          class="cursor-pointer"
          @click="query = keyword; handleSearch()"
        >
          {{ keyword }}
        </n-tag>
      </div>
    </div>

    <n-spin v-if="hasSearched" :show="loading">
      <div class="text-sm text-gray-500 mb-4">
        找到 {{ total }} 個結果
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <NovelCard v-for="novel in results" :key="novel.id" :novel="novel" />
      </div>
      <n-empty v-if="!loading && results.length === 0" description="沒有找到相關小說" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NInput, NIcon, NTag, NEmpty } from 'naive-ui'
import { Search as SearchIcon } from '@vicons/ionicons5'
import { useDebounceFn } from '@vueuse/core'

useHead({ title: '搜尋 — Palimpsest' })

const route = useRoute()
const router = useRouter()

const query = ref((route.query.q as string) || '')
const hasSearched = ref(false)
const { results, hotKeywords, suggestions, loading, total, search, fetchHotKeywords, fetchSuggestions } = useSearch()

function handleSearch() {
  if (!query.value.trim()) return
  hasSearched.value = true
  router.replace({ query: { q: query.value } })
  search(query.value)
}

const handleInput = useDebounceFn((val: string) => {
  if (val.trim().length >= 2) {
    fetchSuggestions(val)
  }
}, 300)

onMounted(() => {
  fetchHotKeywords()
  if (query.value) handleSearch()
})
</script>
