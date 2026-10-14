<template>
  <div class="space-y-8">
    <n-spin :show="pending">
      <n-alert v-if="error" type="error" title="無法載入首頁" class="mb-4">
        請稍後再試。
      </n-alert>

      <section v-if="home?.banners?.length" class="mb-8">
        <n-carousel autoplay show-arrow draggable class="rounded-lg overflow-hidden" style="height: 260px">
          <a
            v-for="banner in home.banners"
            :key="banner.id"
            :href="bannerHref(banner)"
            :target="banner.link_type === 'url' ? '_blank' : undefined"
            :rel="banner.link_type === 'url' ? 'noopener' : undefined"
            class="block relative w-full h-full"
            data-testid="home-banner"
            @click="onBannerClick($event, banner)"
          >
            <img :src="banner.image_url" :alt="banner.title" class="w-full h-full object-cover">
            <div class="absolute bottom-0 left-0 right-0 px-6 py-3 text-white text-lg font-semibold bg-gradient-to-t from-black/60 to-transparent">
              {{ banner.title }}
            </div>
          </a>
        </n-carousel>
      </section>

      <template v-for="section in sections" :key="section.key">
        <section v-if="section.items.length" class="mb-8" :data-testid="`home-section-${section.key}`">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-bold">{{ section.title }}</h2>
            <NuxtLink v-if="section.more" :to="section.more" class="text-primary text-sm">查看更多</NuxtLink>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <NovelCard v-for="novel in section.items" :key="novel.id" :novel="novel" />
          </div>
        </section>
      </template>

      <n-empty v-if="!pending && !error && sections.every(s => !s.items.length)" description="目前還沒有小說" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NCarousel, NAlert, NEmpty } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'
import type { ApiBanner, ApiHomePage } from '~/types/models'
import type { Novel } from '~/types/novel'

useHead({ title: 'Palimpsest — 小說閱讀' })

const { data: home, pending, error } = await useAsyncData('home', async () => {
  const res = await apiFetch<ApiResponse<ApiHomePage>>('/home')
  return res.data
})

const sections = computed(() => {
  const h = home.value
  const list = (items?: unknown[]) => (items ?? []) as Novel[]
  return [
    { key: 'featured', title: '編輯推薦', items: list(h?.featured), more: '' },
    { key: 'popular', title: '熱門推薦', items: list(h?.popular), more: '/ranking/views' },
    { key: 'latest', title: '最新更新', items: list(h?.latest_updates), more: '/ranking/latest' },
    { key: 'new', title: '新書上架', items: list(h?.new_arrivals), more: '' },
    { key: 'completed', title: '完結精選', items: list(h?.completed), more: '/ranking/completed' },
  ]
})

function bannerHref(banner: ApiBanner): string {
  const value = banner.link_value ?? ''
  switch (banner.link_type) {
    case 'novel': return value ? `/novel/${value}` : '#'
    case 'category': return value ? `/category/${value}` : '#'
    case 'url': return /^https?:\/\//i.test(value) ? value : '#'
    default: return '#'
  }
}

function onBannerClick(event: MouseEvent, banner: ApiBanner) {
  const href = bannerHref(banner)
  if (href === '#') {
    event.preventDefault()
    return
  }
  if (banner.link_type !== 'url') {
    event.preventDefault()
    navigateTo(href)
  }
}
</script>
