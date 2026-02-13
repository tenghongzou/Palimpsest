<template>
  <div>
    <h1 class="text-xl font-bold mb-4">排行榜</h1>
    <div class="flex flex-wrap gap-3">
      <NuxtLink
        v-for="rt in rankingTypes"
        :key="rt.key"
        :to="`/ranking/${rt.key}`"
        class="no-underline"
      >
        <n-card hoverable size="small" class="cursor-pointer">
          {{ rt.label }}
        </n-card>
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NCard } from 'naive-ui'

useHead({ title: '排行榜 — Palimpsest' })

const rankingTypes = [
  { key: 'views', label: '人氣榜' },
  { key: 'favorites', label: '收藏榜' },
  { key: 'rating', label: '評分榜' },
  { key: 'latest', label: '更新榜' },
  { key: 'completed', label: '完結榜' },
]
</script>
