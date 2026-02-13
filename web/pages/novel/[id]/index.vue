<template>
  <n-spin :show="loading">
    <div v-if="novel" class="space-y-6">
      <div class="flex gap-6">
        <n-image
          :src="novel.cover_url || '/placeholder-cover.png'"
          :alt="novel.title"
          width="200"
          height="280"
          object-fit="cover"
          class="rounded shadow flex-shrink-0"
          preview-disabled
        />
        <div class="flex-1 space-y-3">
          <h1 class="text-2xl font-bold">{{ novel.title }}</h1>
          <div class="text-gray-500">{{ novel.author_name }}</div>
          <div class="flex items-center gap-3">
            <n-tag :type="statusType" size="small">{{ statusLabel }}</n-tag>
            <span class="text-sm text-gray-400">{{ formatWords(novel.total_words) }}</span>
            <span class="text-sm text-gray-400">{{ novel.total_chapters }} 章</span>
          </div>
          <div class="flex items-center gap-2">
            <n-rate :value="novel.avg_rating" readonly allow-half />
            <span class="text-sm text-gray-500">{{ novel.avg_rating?.toFixed(1) }}</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <n-tag v-for="cat in novel.categories" :key="cat.id" size="small" round>
              {{ cat.name }}
            </n-tag>
            <n-tag v-for="tag in novel.tags" :key="tag.id" size="small" round type="info">
              {{ tag.name }}
            </n-tag>
          </div>
          <div class="flex gap-3 mt-4">
            <n-button type="primary" @click="startReading">開始閱讀</n-button>
            <n-button @click="handleAddBookshelf" :loading="addingBookshelf">
              加入書架
            </n-button>
          </div>
        </div>
      </div>

      <n-card title="簡介">
        <p class="whitespace-pre-wrap text-gray-600">{{ novel.description }}</p>
      </n-card>

      <n-card>
        <template #header>
          <div class="flex items-center justify-between">
            <span>章節列表</span>
            <n-button text size="small" @click="sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'">
              {{ sortOrder === 'asc' ? '正序' : '倒序' }}
            </n-button>
          </div>
        </template>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
          <NuxtLink
            v-for="ch in sortedChapters"
            :key="ch.id"
            :to="`/read/${ch.id}`"
            class="px-3 py-2 rounded hover:bg-gray-100 text-sm truncate block"
          >
            第{{ ch.chapter_number }}章 {{ ch.title }}
          </NuxtLink>
        </div>
      </n-card>
    </div>
  </n-spin>
</template>

<script setup lang="ts">
import { NSpin, NImage, NTag, NRate, NButton, NCard, useMessage } from 'naive-ui'

const route = useRoute()
const router = useRouter()
const novelId = route.params.id as string
const message = useMessage()

const { novel, chapters, loading } = useNovel(novelId)
const { addToBookshelf } = useBookshelf()
const addingBookshelf = ref(false)
const sortOrder = ref<'asc' | 'desc'>('asc')

const sortedChapters = computed(() => {
  const list = [...chapters.value]
  return sortOrder.value === 'desc' ? list.reverse() : list
})

useHead({ title: computed(() => novel.value ? `${novel.value.title} — Palimpsest` : 'Palimpsest') })

const statusMap: Record<string, { label: string; type: 'success' | 'warning' | 'info' }> = {
  ongoing: { label: '連載中', type: 'success' },
  completed: { label: '已完結', type: 'info' },
  hiatus: { label: '暫停', type: 'warning' },
}

const statusLabel = computed(() => novel.value ? (statusMap[novel.value.status]?.label || novel.value.status) : '')
const statusType = computed(() => novel.value ? (statusMap[novel.value.status]?.type || 'info') : 'info')

function formatWords(count: number): string {
  if (count >= 10000) return `${(count / 10000).toFixed(1)}萬字`
  return `${count}字`
}

function startReading() {
  if (chapters.value.length > 0) {
    router.push(`/read/${chapters.value[0].id}`)
  }
}

async function handleAddBookshelf() {
  addingBookshelf.value = true
  try {
    await addToBookshelf(novelId)
    message.success('已加入書架')
  }
  catch {
    message.error('加入書架失敗')
  }
  finally {
    addingBookshelf.value = false
  }
}
</script>
