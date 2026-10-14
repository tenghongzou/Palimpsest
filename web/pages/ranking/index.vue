<template>
  <div>
    <h1 class="text-xl font-bold mb-4">{{ $t('ranking.title') }}</h1>
    <div class="flex flex-wrap gap-3">
      <NuxtLink
        v-for="rt in RANKING_TYPES"
        :key="rt.key"
        :to="`/ranking/${rt.key}`"
        class="no-underline"
      >
        <n-card hoverable size="small" class="cursor-pointer">
          {{ $t(rt.labelKey) }}
        </n-card>
      </NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NCard } from 'naive-ui'

const { t } = useI18n()
useHead({ title: () => t('ranking.title') })
</script>
