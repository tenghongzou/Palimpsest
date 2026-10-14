<template>
  <n-spin :show="loading">
    <n-result v-if="notFound" status="404" title="找不到這本小說" description="它可能已被下架或網址有誤。">
      <template #footer>
        <n-button @click="navigateTo('/')">回到首頁</n-button>
      </template>
    </n-result>
    <div v-else-if="novel" class="space-y-6">
      <div class="flex flex-col sm:flex-row gap-6">
        <NovelCover :src="novel.cover_url" :alt="novel.title" :width="200" :height="280" class="shadow" />
        <div class="flex-1 space-y-3">
          <h1 class="text-2xl font-bold" data-testid="novel-title">{{ novel.title }}</h1>
          <div class="text-gray-500">{{ novel.author_name }}</div>
          <div class="flex items-center gap-3 flex-wrap">
            <n-tag :type="NOVEL_STATUS[novel.status]?.type || 'info'" size="small">{{ NOVEL_STATUS[novel.status]?.label || novel.status }}</n-tag>
            <span class="text-sm text-gray-400">{{ formatWordCount(novel.total_words ?? 0) }}</span>
            <span class="text-sm text-gray-400">{{ novel.total_chapters ?? chapters.length }} 章</span>
            <span class="text-sm text-gray-400">{{ formatViewCount(novel.view_count ?? 0) }} 次閱讀</span>
            <span class="text-sm text-gray-400">{{ novel.favorite_count ?? 0 }} 收藏</span>
          </div>
          <div class="flex items-center gap-2">
            <n-rate :value="novel.avg_rating ?? 0" readonly allow-half />
            <span class="text-sm text-gray-500">{{ (novel.avg_rating ?? 0).toFixed(1) }}</span>
            <span class="text-sm text-gray-400">（{{ novel.review_count ?? 0 }} 則書評）</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <NuxtLink v-for="cat in novel.categories" :key="cat.id" :to="`/category/${cat.slug}`" class="no-underline">
              <n-tag size="small" round class="cursor-pointer">{{ cat.name }}</n-tag>
            </NuxtLink>
            <n-tag v-for="tag in visibleTags" :key="tag.id" size="small" round type="info">
              {{ tag.name }}
            </n-tag>
          </div>
          <div v-if="novel.latest_chapter_title" class="text-sm text-gray-500">
            最新章節：{{ novel.latest_chapter_title }}
            <span v-if="novel.latest_chapter_at" class="text-gray-400">（{{ formatRelativeTime(novel.latest_chapter_at) }}）</span>
          </div>
          <div class="flex gap-3 mt-4 flex-wrap">
            <n-button type="primary" :disabled="!chapters.length" data-testid="start-reading" @click="startReading">
              {{ resume ? '繼續閱讀' : '開始閱讀' }}
            </n-button>
            <n-button v-if="resume" data-testid="read-from-start" @click="readFromStart">從頭閱讀</n-button>
            <n-button :loading="addingBookshelf" :disabled="inBookshelf" data-testid="add-bookshelf" @click="handleAddBookshelf">
              {{ inBookshelf ? '已在書架' : '加入書架' }}
            </n-button>
          </div>
          <div v-if="resume" class="text-xs text-gray-400" data-testid="resume-hint">
            上次讀到：{{ resume.title }}
          </div>
        </div>
      </div>

      <n-card title="簡介">
        <p class="whitespace-pre-wrap text-gray-600">{{ novel.description || '暫無簡介' }}</p>
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
            :class="{ 'font-semibold text-primary': resume?.chapterId === ch.id }"
            data-testid="chapter-link"
          >
            {{ chapterLabel(ch.chapter_number, ch.title) }}
          </NuxtLink>
        </div>
        <n-empty v-if="!chapters.length" description="尚無章節" />
      </n-card>

      <NovelReviews :novel-id="novelId" @changed="fetchNovel()" />
    </div>
  </n-spin>
</template>

<script setup lang="ts">
import { NSpin, NTag, NRate, NButton, NCard, NEmpty, NResult, useMessage } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'
import type { ApiReadingProgress } from '~/types/models'
import { getProgress } from '~/utils/localDb'
import { NOVEL_STATUS, chapterLabel, formatRelativeTime, formatViewCount, formatWordCount } from '~/utils/format'

const route = useRoute()
const router = useRouter()
const novelId = route.params.id as string
const message = useMessage()
const authStore = useAuthStore()

const { novel, chapters, loading, error, fetchNovel } = useNovel(novelId)
// A tag named like one of the categories would only repeat it.
const visibleTags = computed(() => {
  const n = novel.value
  if (!n) return []
  const categoryNames = new Set((n.categories ?? []).map(c => c.name))
  return (n.tags ?? []).filter(t => !categoryNames.has(t.name))
})
const { addToBookshelf } = useBookshelf()
const { readDb } = useLocalDb()
const addingBookshelf = ref(false)
const inBookshelf = ref(false)
const sortOrder = ref<'asc' | 'desc'>('asc')
const progress = ref<{ chapter_id: string, paragraph_index?: number } | null>(null)

const notFound = computed(() => statusOf(error.value) === 404 || statusOf(error.value) === 400)

const sortedChapters = computed(() => {
  const list = [...chapters.value]
  return sortOrder.value === 'desc' ? list.reverse() : list
})

/** Where "繼續閱讀" goes: the saved progress, if its chapter is still listed. */
const resume = computed(() => {
  const p = progress.value
  if (!p) return null
  const ch = chapters.value.find(c => c.id === p.chapter_id)
  if (!ch) return null
  return { chapterId: ch.id, paragraph: p.paragraph_index ?? 0, title: chapterLabel(ch.chapter_number, ch.title) }
})

useHead({ title: computed(() => novel.value ? `${novel.value.title} — Palimpsest` : 'Palimpsest') })

async function loadProgress() {
  const local = await readDb(db => getProgress(db, novelId)).catch(() => null)
  if (local) progress.value = local
  if (!authStore.isLoggedIn) return
  try {
    const res = await apiFetch<ApiResponse<ApiReadingProgress>>(`/reading-progress/${novelId}`)
    const server = res.data
    // Last read wins, as on the server.
    if (!local || (server.read_at && new Date(server.read_at) > new Date(local.read_at))) {
      progress.value = server
    }
  }
  catch {
    // 404: never read this novel.
  }
}

async function loadShelfState() {
  if (!authStore.isLoggedIn) return
  try {
    const res = await apiFetch<ApiResponse<{ novel_id: string }[]>>('/bookshelf')
    inBookshelf.value = res.data.some(i => i.novel_id === novelId)
  }
  catch {}
}

function startReading() {
  if (resume.value) {
    router.push({
      path: `/read/${resume.value.chapterId}`,
      query: resume.value.paragraph > 0 ? { p: String(resume.value.paragraph) } : undefined,
    })
    return
  }
  readFromStart()
}

function readFromStart() {
  const first = chapters.value[0]
  if (first) router.push(`/read/${first.id}`)
}

async function handleAddBookshelf() {
  if (!authStore.isLoggedIn) {
    router.push(`/login?redirect=${encodeURIComponent(route.fullPath)}`)
    return
  }
  addingBookshelf.value = true
  try {
    await addToBookshelf(novelId)
    inBookshelf.value = true
    message.success('已加入書架')
  }
  catch (e) {
    if (statusOf(e) === 409) {
      inBookshelf.value = true
      message.info('這本書已經在書架上了')
    }
    else {
      message.error(describeError(e, { 404: '找不到這本小說' }, '加入書架失敗'))
    }
  }
  finally {
    addingBookshelf.value = false
  }
}

onMounted(() => {
  void loadProgress()
  void loadShelfState()
})
</script>
