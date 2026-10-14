<template>
  <div class="space-y-4" data-testid="reader-settings-form">
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">字體大小</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.fontSize" v-bind="L.fontSize" @update:value="set('fontSize', $event)" />
        <span class="w-10 text-right text-sm" data-testid="font-size-value">{{ s.fontSize }}</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">行高</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.lineHeight" v-bind="L.lineHeight" @update:value="set('lineHeight', $event)" />
        <span class="w-10 text-right text-sm">{{ s.lineHeight.toFixed(1) }}</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">字距</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.letterSpacing" v-bind="L.letterSpacing" @update:value="set('letterSpacing', $event)" />
        <span class="w-10 text-right text-sm">{{ s.letterSpacing }}</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">頁邊距</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.margin" v-bind="L.margin" @update:value="set('margin', $event)" />
        <span class="w-10 text-right text-sm">{{ s.margin }}</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span class="flex-shrink-0">亮度</span>
      <div class="flex items-center gap-3 flex-1 max-w-80">
        <n-slider :value="s.brightness" v-bind="L.brightness" @update:value="set('brightness', $event)" />
        <span class="w-10 text-right text-sm">{{ s.brightness }}%</span>
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>主題</span>
      <div class="flex gap-2">
        <button
          v-for="(t, key) in READER_THEMES"
          :key="key"
          type="button"
          class="w-8 h-8 rounded-full border-2 cursor-pointer"
          :class="s.theme === key ? 'border-blue-500' : 'border-gray-300'"
          :style="{ backgroundColor: t.bg }"
          :title="t.label"
          :aria-label="t.label"
          :data-testid="`theme-${key}`"
          @click="set('theme', key)"
        />
      </div>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>字體</span>
      <n-select :value="s.fontFamily" :options="fontOptions" size="small" class="w-32" @update:value="set('fontFamily', $event)" />
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>閱讀模式</span>
      <n-radio-group :value="s.readingMode" size="small" @update:value="set('readingMode', $event)">
        <n-radio-button value="scroll">捲動</n-radio-button>
        <n-radio-button value="page">翻頁</n-radio-button>
      </n-radio-group>
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>自動進入下一章</span>
      <n-switch :value="s.autoChapter" @update:value="set('autoChapter', $event)" />
    </div>
    <div class="flex items-center justify-between gap-4">
      <span>保持螢幕常亮</span>
      <n-switch :value="s.keepScreenOn" @update:value="set('keepScreenOn', $event)" />
    </div>
    <div class="flex justify-end">
      <n-button size="small" @click="readerStore.resetSettings()">重置為預設</n-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NSlider, NSelect, NSwitch, NRadioGroup, NRadioButton, NButton } from 'naive-ui'
import { FONT_FAMILIES, READER_THEMES, SETTING_LIMITS as L, type ReaderSettings } from '~/utils/readingSettings'

const readerStore = useReaderStore()
const s = computed(() => readerStore.settings)

const fontOptions = Object.entries(FONT_FAMILIES).map(([value, f]) => ({ label: f.label, value }))

function set<K extends keyof ReaderSettings>(key: K, value: ReaderSettings[K]) {
  readerStore.updateSettings({ [key]: value } as Partial<ReaderSettings>)
}
</script>
