<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">{{ $t('category.heading') }}</h1>
    <n-spin :show="loading">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <n-card v-for="cat in categories" :key="cat.id" size="small">
          <template #header>
            <NuxtLink :to="`/category/${cat.slug}`" class="text-base font-semibold">{{ cat.name }}</NuxtLink>
          </template>
          <div v-if="cat.children?.length" class="flex flex-wrap gap-2">
            <NuxtLink v-for="child in cat.children" :key="child.id" :to="`/category/${child.slug}`" class="no-underline">
              <n-tag size="small" class="cursor-pointer">{{ child.name }}</n-tag>
            </NuxtLink>
          </div>
        </n-card>
      </div>
      <n-empty v-if="!loading && categories.length === 0" :description="$t('category.empty')" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NSpin, NCard, NEmpty, NTag } from 'naive-ui'

const { t } = useI18n()
useHead({ title: () => t('category.title') })
const { categories, loading } = useCategories()
</script>
