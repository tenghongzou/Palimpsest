<template>
  <div class="space-y-8">
    <section>
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xl font-bold">熱門推薦</h2>
        <NuxtLink to="/ranking/views" class="text-primary text-sm">查看更多</NuxtLink>
      </div>
      <n-spin :show="hotLoading">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <NovelCard v-for="novel in hotNovels" :key="novel.id" :novel="novel" />
        </div>
      </n-spin>
    </section>

    <section>
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xl font-bold">最新更新</h2>
        <NuxtLink to="/ranking/latest" class="text-primary text-sm">查看更多</NuxtLink>
      </div>
      <n-spin :show="latestLoading">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <NovelCard v-for="novel in latestNovels" :key="novel.id" :novel="novel" />
        </div>
      </n-spin>
    </section>

    <section>
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xl font-bold">已完結精選</h2>
        <NuxtLink to="/ranking/completed" class="text-primary text-sm">查看更多</NuxtLink>
      </div>
      <n-spin :show="completedLoading">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <NovelCard v-for="novel in completedNovels" :key="novel.id" :novel="novel" />
        </div>
      </n-spin>
    </section>
  </div>
</template>

<script setup lang="ts">
import { NSpin } from 'naive-ui'

useHead({ title: 'Palimpsest — 小說閱讀' })

const { novels: hotNovels, loading: hotLoading, fetchNovels: fetchHot } = useNovelList()
const { novels: latestNovels, loading: latestLoading, fetchNovels: fetchLatest } = useNovelList()
const { novels: completedNovels, loading: completedLoading, fetchNovels: fetchCompleted } = useNovelList()

onMounted(() => {
  fetchHot({ sort: 'views', page_size: 6 })
  fetchLatest({ sort: 'latest', page_size: 6 })
  fetchCompleted({ status: 'completed', sort: 'rating', page_size: 6 })
})
</script>
