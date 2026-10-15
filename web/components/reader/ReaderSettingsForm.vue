<template>
  <div class="space-y-4" data-testid="reader-settings-form">
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">{{ $t('reader.settings.fontSize') }}</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.fontSize" v-bind="L.fontSize" @update:value="set('fontSize', $event)" />
        <span class="w-10 text-right text-sm" data-testid="font-size-value">{{ s.fontSize }}</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">{{ $t('reader.settings.lineHeight') }}</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.lineHeight" v-bind="L.lineHeight" @update:value="set('lineHeight', $event)" />
        <span class="w-10 text-right text-sm">{{ s.lineHeight.toFixed(1) }}</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">{{ $t('reader.settings.letterSpacing') }}</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.letterSpacing" v-bind="L.letterSpacing" @update:value="set('letterSpacing', $event)" />
        <span class="w-10 text-right text-sm">{{ s.letterSpacing }}</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">{{ $t('reader.settings.margin') }}</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.margin" v-bind="L.margin" @update:value="set('margin', $event)" />
        <span class="w-10 text-right text-sm">{{ s.margin }}</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">{{ $t('reader.settings.brightness') }}</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.brightness" v-bind="L.brightness" @update:value="set('brightness', $event)" />
        <span class="w-10 text-right text-sm">{{ s.brightness }}%</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>{{ $t('reader.settings.theme') }}</span>
      <div class="flex gap-2">
        <button
          v-for="(theme, key) in READER_THEMES"
          :key="key"
          type="button"
          class="w-8 h-8 rounded-full border-2 cursor-pointer"
          :class="s.theme === key ? 'border-blue-500' : 'border-gray-300'"
          :style="{ backgroundColor: theme.bg }"
          :title="$t(`reader.settings.themes.${key}`)"
          :aria-label="$t(`reader.settings.themes.${key}`)"
          :data-testid="`theme-${key}`"
          @click="set('theme', key)"
        />
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>{{ $t('reader.settings.font') }}</span>
      <n-select :value="s.fontFamily" :options="fontOptions" size="small" class="w-32" @update:value="set('fontFamily', $event)" />
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>{{ $t('reader.settings.readingMode') }}</span>
      <n-radio-group :value="s.readingMode" size="small" @update:value="set('readingMode', $event)">
        <n-radio-button value="scroll">{{ $t('reader.settings.modeScroll') }}</n-radio-button>
        <n-radio-button value="page">{{ $t('reader.settings.modePage') }}</n-radio-button>
      </n-radio-group>
    </div>
    <div v-if="s.readingMode === 'page'" class="flex items-center justify-between gap-4" data-testid="page-animation-setting">
      <span class="flex-shrink-0">{{ $t('reader.settings.pageAnimation') }}</span>
      <n-radio-group :value="s.pageAnimation" size="small" @update:value="set('pageAnimation', $event)">
        <n-radio-button v-for="a in PAGE_ANIMATIONS" :key="a" :value="a" :data-testid="`page-animation-${a}`">
          {{ $t(`reader.settings.animations.${a}`) }}
        </n-radio-button>
      </n-radio-group>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>{{ $t('reader.settings.autoChapter') }}</span>
      <n-switch :value="s.autoChapter" @update:value="set('autoChapter', $event)" />
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>{{ $t('reader.settings.keepScreenOn') }}</span>
      <n-switch :value="s.keepScreenOn" @update:value="set('keepScreenOn', $event)" />
    </div>
    <div class="flex justify-end">
      <n-button size="small" @click="readerStore.resetSettings()">{{ $t('reader.settings.reset') }}</n-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NSlider, NSelect, NSwitch, NRadioGroup, NRadioButton, NButton } from 'naive-ui'
import { FONT_FAMILIES, PAGE_ANIMATIONS, READER_THEMES, SETTING_LIMITS as L, type ReaderSettings } from '~/utils/readingSettings'

const { t } = useI18n()
const readerStore = useReaderStore()
const s = computed(() => readerStore.settings)

const fontOptions = computed(() => Object.keys(FONT_FAMILIES).map(value => ({ label: t(`reader.settings.fonts.${value}`), value })))

function set<K extends keyof ReaderSettings>(key: K, value: ReaderSettings[K]) {
  readerStore.updateSettings({ [key]: value } as Partial<ReaderSettings>)
}
</script>
