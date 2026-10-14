<template>
  <n-config-provider :theme="naiveTheme" :theme-overrides="naiveTheme ? brandDarkThemeOverrides : brandThemeOverrides" :locale="naiveLocale" :date-locale="naiveDateLocale">
    <n-message-provider>
      <PwaPrompt />
      <n-dialog-provider>
        <div
          class="min-h-screen reader-layout"
          :style="{
            backgroundColor: theme.bg,
            color: theme.text,
          }"
        >
          <slot />
          <!-- Dims the page without `filter`, which would break fixed positioning inside. -->
          <div
            v-if="settings.brightness < 100"
            class="fixed inset-0 pointer-events-none z-40"
            :style="{ backgroundColor: `rgba(0, 0, 0, ${(100 - settings.brightness) / 100 * 0.8})` }"
          />
        </div>
      </n-dialog-provider>
    </n-message-provider>
  </n-config-provider>
</template>

<script setup lang="ts">
import { NConfigProvider, NMessageProvider, NDialogProvider, darkTheme } from 'naive-ui'
import { READER_THEMES } from '~/utils/readingSettings'

const { naiveLocale, naiveDateLocale } = useNaiveLocale()
const readerStore = useReaderStore()
const settings = computed(() => readerStore.settings)
const theme = computed(() => READER_THEMES[settings.value.theme] ?? READER_THEMES.white)
// Drawers, toolbar and messages follow the dark reader themes.
const naiveTheme = computed(() => settings.value.theme === 'dark' || settings.value.theme === 'black' ? darkTheme : null)
</script>
