<template>
  <n-config-provider :theme-overrides="brandThemeOverrides" :locale="naiveLocale" :date-locale="naiveDateLocale">
    <n-message-provider>
      <PwaPrompt />
      <div class="min-h-screen flex items-center justify-center bg-gray-50">
        <div class="w-full max-w-md px-4">
          <div class="text-center mb-8">
            <h1 class="text-3xl font-bold text-gray-800">Palimpsest</h1>
            <p class="text-gray-500 mt-2">{{ $t('layout.auth.subtitle') }}</p>
            <LanguageSwitcher class="mt-3" />
          </div>
          <n-card>
            <slot />
          </n-card>
        </div>
      </div>
    </n-message-provider>
  </n-config-provider>
</template>

<script setup lang="ts">
import { NConfigProvider, NMessageProvider, NCard } from 'naive-ui'

const { naiveLocale, naiveDateLocale } = useNaiveLocale()
</script>
