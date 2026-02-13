<template>
  <div class="flex items-center justify-between text-sm text-gray-500">
    <div class="flex items-center gap-4">
      <span>&copy; {{ year }} Palimpsest</span>
      <NuxtLink to="/about" class="text-gray-500 hover:text-primary">關於</NuxtLink>
      <NuxtLink to="/terms" class="text-gray-500 hover:text-primary">服務條款</NuxtLink>
      <NuxtLink to="/privacy" class="text-gray-500 hover:text-primary">隱私政策</NuxtLink>
    </div>
    <div class="flex items-center gap-2">
      <n-button
        v-for="lang in languages"
        :key="lang.value"
        text
        :type="locale === lang.value ? 'primary' : 'default'"
        size="tiny"
        @click="setLocale(lang.value)"
      >
        {{ lang.label }}
      </n-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NButton } from 'naive-ui'

const appStore = useAppStore()
const locale = computed(() => appStore.locale)
const year = new Date().getFullYear()

const languages = [
  { label: '繁體中文', value: 'zh-TW' as const },
  { label: '简体中文', value: 'zh-CN' as const },
  { label: 'English', value: 'en' as const },
]

function setLocale(lang: 'zh-TW' | 'zh-CN' | 'en') {
  appStore.setLocale(lang)
}
</script>
