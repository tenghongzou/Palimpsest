<template>
  <div class="min-h-screen" @click="toggleToolbar">
    <n-spin :show="loading" class="min-h-screen">
      <template v-if="chapter">
        <ReaderContent
          :content="displayContent"
          :title="chapter.title"
          :settings="settings"
        />

        <div class="text-center py-8 space-x-4">
          <n-button @click.stop="goPrevChapter">上一章</n-button>
          <n-button type="primary" @click.stop="goNextChapter">下一章</n-button>
        </div>
      </template>
    </n-spin>

    <ReaderToolbar
      :visible="showToolbar"
      @prev="goPrevChapter"
      @next="goNextChapter"
      @open-settings="showSettings = true"
      @open-chapter-list="showChapterList = true"
      @toggle-bookmark="saveProgress"
      @translate="showTranslate = true"
    />

    <n-drawer v-model:show="showSettings" placement="bottom" height="auto">
      <n-drawer-content title="閱讀設定">
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <span>字體大小</span>
            <n-slider v-model:value="localSettings.fontSize" :min="12" :max="32" :step="1" class="w-48" />
          </div>
          <div class="flex items-center justify-between">
            <span>行高</span>
            <n-slider v-model:value="localSettings.lineHeight" :min="1.2" :max="3" :step="0.1" class="w-48" />
          </div>
          <div class="flex items-center justify-between">
            <span>主題</span>
            <div class="flex gap-2">
              <div
                v-for="t in themes"
                :key="t.key"
                class="w-8 h-8 rounded-full border-2 cursor-pointer"
                :class="localSettings.theme === t.key ? 'border-primary' : 'border-gray-200'"
                :style="{ backgroundColor: t.color }"
                @click="localSettings.theme = t.key"
              />
            </div>
          </div>
          <div class="flex items-center justify-between">
            <span>字體</span>
            <n-select v-model:value="localSettings.fontFamily" :options="fontOptions" size="small" class="w-32" />
          </div>
        </div>
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showChapterList" placement="left" width="300">
      <n-drawer-content title="章節目錄">
        <div class="space-y-1">
          <div
            v-for="ch in chapterList"
            :key="ch.id"
            class="px-3 py-2 rounded cursor-pointer text-sm"
            :class="ch.id === chapter?.id ? 'bg-primary text-white' : 'hover:bg-gray-100'"
            @click="navigateToChapter(ch.id)"
          >
            第{{ ch.chapter_number }}章 {{ ch.title }}
          </div>
        </div>
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showTranslate" placement="bottom" height="auto">
      <n-drawer-content title="翻譯">
        <div class="space-y-3">
          <n-select v-model:value="targetLang" :options="langOptions" />
          <n-button type="primary" block :loading="translating" @click="handleTranslate">
            翻譯本章
          </n-button>
        </div>
      </n-drawer-content>
    </n-drawer>
  </div>
</template>

<script setup lang="ts">
import {
  NSpin, NButton, NDrawer, NDrawerContent,
  NSlider, NSelect,
} from 'naive-ui'
import type { Chapter } from '~/types/novel'

definePageMeta({ layout: 'reader' })

const route = useRoute()
const router = useRouter()
const chapterId = computed(() => route.params.chapterId as string)
const readerStore = useReaderStore()

const { chapter, loading, settings, goNextChapter, goPrevChapter, saveProgress } = useReader(chapterId)
const { translating, translateChapter } = useTranslation()

const showToolbar = ref(false)
const showSettings = ref(false)
const showChapterList = ref(false)
const showTranslate = ref(false)
const translatedContent = ref<string | null>(null)
const targetLang = ref('zh-CN')
const chapterList = ref<Chapter[]>([])

const localSettings = reactive({ ...readerStore.settings })

watch(localSettings, (val) => {
  readerStore.updateSettings(val)
}, { deep: true })

useHead({ title: computed(() => chapter.value ? `${chapter.value.title} — 閱讀` : '閱讀中...') })

const displayContent = computed(() => translatedContent.value || chapter.value?.content || '')

const themes = [
  { key: 'white' as const, color: '#ffffff' },
  { key: 'yellow' as const, color: '#f5f0e0' },
  { key: 'green' as const, color: '#e0f0e0' },
  { key: 'dark' as const, color: '#2c2c2c' },
  { key: 'black' as const, color: '#000000' },
]

const fontOptions = [
  { label: '系統字體', value: 'system' },
  { label: '宋體', value: 'song' },
  { label: '楷體', value: 'kai' },
  { label: '襯線', value: 'serif' },
]

const langOptions = [
  { label: '簡體中文', value: 'zh-CN' },
  { label: '繁體中文', value: 'zh-TW' },
  { label: 'English', value: 'en' },
]

function toggleToolbar() {
  showToolbar.value = !showToolbar.value
}

function navigateToChapter(id: string) {
  showChapterList.value = false
  translatedContent.value = null
  router.push(`/read/${id}`)
}

async function handleTranslate() {
  if (!chapter.value) return
  const content = await translateChapter(chapter.value.id, targetLang.value)
  translatedContent.value = content
  showTranslate.value = false
}

watch(chapterId, () => {
  translatedContent.value = null
})

watch(chapter, async (ch) => {
  if (ch) {
    const res = await $fetch<{ code: number; data: Chapter[] }>(`/api/v1/novels/${ch.novel_id}/chapters`, {
      params: { order: 'asc' },
    })
    chapterList.value = res.data
    saveProgress()
  }
})
</script>
