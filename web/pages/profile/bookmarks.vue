<template>
  <div class="max-w-3xl mx-auto space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">我的書籤</h1>
      <n-button text @click="navigateTo('/profile')">返回個人中心</n-button>
    </div>

    <n-spin :show="loading">
      <div v-for="group in groups" :key="group.novelId" class="mb-6">
        <NuxtLink :to="`/novel/${group.novelId}`" class="font-semibold text-base block mb-2">
          {{ group.title }}
        </NuxtLink>
        <BookmarkList :bookmarks="group.bookmarks" @open="open" @remove="remove" />
      </div>
      <n-empty v-if="!loading && groups.length === 0" description="還沒有書籤，閱讀時點擊書籤按鈕即可加入" class="py-12" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NButton, NSpin, NEmpty, useMessage } from 'naive-ui'
import type { LocalBookmark } from '~/utils/localDb'

definePageMeta({ middleware: 'auth' })
useHead({ title: '我的書籤 — Palimpsest' })

const message = useMessage()
const { list, remove: removeBookmark, refresh } = useBookmarks()
const bookmarks = ref<LocalBookmark[]>([])
const titles = ref<Record<string, string>>({})
const loading = ref(false)

const groups = computed(() => {
  const map = new Map<string, LocalBookmark[]>()
  for (const b of bookmarks.value) {
    if (!map.has(b.novel_id)) map.set(b.novel_id, [])
    map.get(b.novel_id)!.push(b)
  }
  return [...map.entries()].map(([novelId, list]) => ({
    novelId,
    title: titles.value[novelId] || '小說',
    bookmarks: list,
  }))
})

async function loadTitles() {
  const missing = [...new Set(bookmarks.value.map(b => b.novel_id))].filter(id => !titles.value[id])
  await Promise.all(missing.map(async (id) => {
    try {
      const res = await apiFetch<{ data: { title: string } }>(`/novels/${id}`)
      titles.value = { ...titles.value, [id]: res.data.title }
    }
    catch {}
  }))
}

async function load() {
  loading.value = true
  try {
    await refresh().catch(() => {})
    bookmarks.value = await list()
    void loadTitles()
  }
  catch (e) {
    message.error(describeError(e, {}, '無法載入書籤'))
  }
  finally {
    loading.value = false
  }
}

function open(b: LocalBookmark) {
  navigateTo({ path: `/read/${b.chapter_id}`, query: { p: String(b.paragraph_index) } })
}

async function remove(b: LocalBookmark) {
  try {
    await removeBookmark(b.id)
    bookmarks.value = bookmarks.value.filter(x => x.id !== b.id)
    message.success('已刪除書籤')
  }
  catch (e) {
    message.error(describeError(e, {}, '刪除失敗'))
  }
}

onMounted(load)
</script>
