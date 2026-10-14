<template>
  <n-config-provider :theme-overrides="brandThemeOverrides" :locale="naiveLocale" :date-locale="naiveDateLocale">
    <n-message-provider>
      <PwaPrompt />
      <n-dialog-provider>
        <n-layout class="min-h-screen">
          <n-layout-header bordered class="px-6 py-3">
            <AppHeader />
          </n-layout-header>
          <n-layout-content class="px-6 py-4">
            <slot />
          </n-layout-content>
          <n-layout-footer bordered class="px-6 py-4">
            <AppFooter />
          </n-layout-footer>
        </n-layout>
      </n-dialog-provider>
    </n-message-provider>
  </n-config-provider>
</template>

<script setup lang="ts">
import {
  NConfigProvider, NMessageProvider, NDialogProvider,
  NLayout, NLayoutHeader, NLayoutContent, NLayoutFooter,
} from 'naive-ui'

const { naiveLocale, naiveDateLocale } = useNaiveLocale()
</script>
