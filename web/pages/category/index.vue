<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">小說分類</h1>
    <n-spin :show="loading">
      <div class="flex flex-wrap gap-3">
        <NuxtLink
          v-for="cat in categories"
          :key="cat.id"
          :to="`/category/${cat.slug}`"
          class="no-underline"
        >
          <n-card hoverable size="small" class="cursor-pointer">
            {{ cat.name }}
          </n-card>
        </NuxtLink>
      </div>
      <n-empty v-if="!loading && categories.length === 0" description="暫無分類" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NCard, NEmpty } from 'naive-ui'

useHead({ title: '分類 — Palimpsest' })
const { categories, loading } = useCategories()
</script>
