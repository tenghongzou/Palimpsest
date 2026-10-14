<template>
  <div class="flex items-center justify-between text-sm text-gray-500">
    <div class="flex items-center gap-4">
      <span>&copy; {{ year }} Palimpsest</span>
      <NuxtLink to="/about" class="text-gray-500 hover:text-primary">{{ $t('footer.about') }}</NuxtLink>
      <NuxtLink to="/terms" class="text-gray-500 hover:text-primary">{{ $t('footer.terms') }}</NuxtLink>
      <NuxtLink to="/privacy" class="text-gray-500 hover:text-primary">{{ $t('footer.privacy') }}</NuxtLink>
    </div>
    <div class="flex items-center gap-2" data-testid="footer-languages">
      <n-button
        v-for="lang in options"
        :key="lang.value"
        text
        :type="locale === lang.value ? 'primary' : 'default'"
        size="tiny"
        :lang="lang.value"
        @click="select(lang.value)"
      >
        {{ lang.label }}
      </n-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NButton, useMessage } from 'naive-ui'

const { t } = useI18n()
const message = useMessage()
const { locale, options, changeLanguage } = useLanguage()
const year = new Date().getFullYear()

async function select(code: string) {
  if (code === locale.value) return
  if (await changeLanguage(code) === 'failed') message.warning(t('language.notSavedToAccount'))
}
</script>
