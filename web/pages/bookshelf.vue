<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">我的書架</h1>
      <n-select v-model:value="sortBy" :options="sortOptions" size="small" class="w-32" />
    </div>

    <n-spin :show="loading">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <n-card
          v-for="item in items"
          :key="item.id"
          hoverable
          class="cursor-pointer"
          @click="navigateTo(`/novel/${item.novel_id}`)"
        >
          <div class="flex gap-3">
            <n-image
              :src="item.novel?.cover_url || '/placeholder-cover.png'"
              width="60"
              height="84"
              object-fit="cover"
              class="rounded flex-shrink-0"
              preview-disabled
            />
            <div class="flex-1 min-w-0">
              <div class="font-semibold truncate">{{ item.novel?.title }}</div>
              <div class="text-sm text-gray-500">{{ item.novel?.author_name }}</div>
              <div v-if="item.last_read_at" class="text-xs text-gray-400 mt-1">
                上次閱讀：{{ formatDate(item.last_read_at) }}
              </div>
            </div>
            <n-button
              text
              type="error"
              size="small"
              @click.stop="handleRemove(item.novel_id)"
            >
              移除
            </n-button>
          </div>
        </n-card>
      </div>
      <n-empty v-if="!loading && items.length === 0" description="書架還是空的，去逛逛書城吧">
        <template #extra>
          <n-button type="primary" @click="navigateTo('/')">去看看</n-button>
        </template>
      </n-empty>
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NCard, NImage, NButton, NSelect, NEmpty, useMessage } from 'naive-ui'

definePageMeta({ middleware: 'auth' })
useHead({ title: '書架 — Palimpsest' })

const message = useMessage()
const { items, loading, fetchBookshelf, removeFromBookshelf } = useBookshelf()
const sortBy = ref<'recent' | 'added' | 'title'>('recent')

const sortOptions = [
  { label: '最近閱讀', value: 'recent' },
  { label: '加入時間', value: 'added' },
  { label: '書名排序', value: 'title' },
]

function formatDate(dateStr: string): string {
  const d = new Date(dateStr)
  return d.toLocaleDateString('zh-TW')
}

async function handleRemove(novelId: string) {
  try {
    await removeFromBookshelf(novelId)
    message.success('已從書架移除')
  }
  catch {
    message.error('移除失敗')
  }
}

watch(sortBy, (val) => fetchBookshelf(val), { immediate: true })
</script>
