<template>
  <n-dropdown trigger="click" :options="dropdownOptions" :value="locale" @select="select">
    <n-button quaternary size="small" :title="$t('language.switchTo')" :aria-label="$t('language.switchTo')" data-testid="language-switcher">
      <template #icon>
        <n-icon><LanguageOutline /></n-icon>
      </template>
      {{ currentName }}
    </n-button>
  </n-dropdown>
</template>

<script setup lang="ts">
import { NButton, NDropdown, NIcon, useMessage } from 'naive-ui'
import { LanguageOutline } from '@vicons/ionicons5'
import { LOCALE_NAMES, type AppLocale } from '~/i18n/constants'

const { t } = useI18n()
const message = useMessage()
const { locale, options, changeLanguage } = useLanguage()

const currentName = computed(() => LOCALE_NAMES[locale.value] ?? locale.value)
const dropdownOptions = computed(() => options.map(o => ({
  label: o.label,
  key: o.value,
  props: { 'data-testid': `language-option-${o.value}`, 'lang': o.value },
})))

async function select(key: string) {
  if (key === locale.value) return
  const result = await changeLanguage(key as AppLocale)
  if (result === 'failed') message.warning(t('language.notSavedToAccount'))
}
</script>
