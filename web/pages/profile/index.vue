<template>
  <div class="max-w-2xl mx-auto space-y-6">
    <n-card>
      <div class="flex items-center gap-6">
        <n-avatar :src="user?.avatar_url" :size="80" round />
        <div>
          <h2 class="text-xl font-bold">{{ user?.nickname || user?.username }}</h2>
          <div class="text-gray-500">@{{ user?.username }}</div>
          <div class="text-sm text-gray-400 mt-1">{{ user?.bio || '這個人很懶，什麼都沒寫' }}</div>
        </div>
      </div>
    </n-card>

    <div class="grid grid-cols-3 gap-4">
      <n-card class="text-center">
        <div class="text-2xl font-bold text-primary">{{ formatReadWords }}</div>
        <div class="text-sm text-gray-500 mt-1">累計閱讀</div>
      </n-card>
      <n-card class="text-center">
        <div class="text-2xl font-bold text-primary">{{ formatReadTime }}</div>
        <div class="text-sm text-gray-500 mt-1">閱讀時間</div>
      </n-card>
      <n-card class="text-center">
        <div class="text-2xl font-bold text-primary">{{ bookshelfCount }}</div>
        <div class="text-sm text-gray-500 mt-1">書架藏書</div>
      </n-card>
    </div>

    <n-card>
      <div class="flex items-center justify-between">
        <span>帳號設定</span>
        <n-button text type="primary" @click="navigateTo('/profile/settings')">前往設定</n-button>
      </div>
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { NCard, NAvatar, NButton } from 'naive-ui'

definePageMeta({ middleware: 'auth' })
useHead({ title: '個人中心 — Palimpsest' })

const authStore = useAuthStore()
const user = computed(() => authStore.user)
const { items, fetchBookshelf } = useBookshelf()

const bookshelfCount = computed(() => items.value.length)

const formatReadWords = computed(() => {
  const words = user.value?.total_read_words || 0
  if (words >= 10000) return `${(words / 10000).toFixed(1)}萬字`
  return `${words}字`
})

const formatReadTime = computed(() => {
  const seconds = user.value?.total_read_seconds || 0
  const hours = Math.floor(seconds / 3600)
  if (hours > 0) return `${hours}小時`
  return `${Math.floor(seconds / 60)}分鐘`
})

onMounted(() => fetchBookshelf())
</script>
