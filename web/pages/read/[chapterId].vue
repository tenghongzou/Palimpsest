<template>
  <div class="min-h-screen" @click="onContentClick">
    <div
      class="fixed top-0 left-0 right-0 z-50 transition-transform"
      :class="showToolbar ? 'translate-y-0' : '-translate-y-full'"
      @click.stop
    >
      <div class="max-w-3xl mx-auto px-4 pt-3">
        <n-card size="small" class="shadow">
          <div class="flex items-center justify-between gap-3">
            <NuxtLink v-if="chapter" :to="`/novel/${chapter.novel_id}`" class="text-sm truncate" data-testid="reader-back">
              ‹ {{ novelTitle || '返回小說' }}
            </NuxtLink>
            <span class="text-xs text-gray-500 truncate">{{ chapter?.title }}</span>
          </div>
        </n-card>
      </div>
    </div>

    <n-spin :show="loading" class="min-h-screen">
      <template v-if="chapter">
        <div v-if="offline" class="text-center text-xs text-gray-500 pt-2" data-testid="offline-notice">
          離線模式：顯示的是本機快取的章節
        </div>
        <div v-if="translatedContent" class="text-center text-xs text-gray-500 pt-2">
          目前顯示翻譯內容
          <n-button text size="tiny" type="primary" @click.stop="translatedContent = null">顯示原文</n-button>
        </div>
        <ReaderContent
          :content="displayContent"
          :title="translatedTitle || chapter.title"
          :settings="settings"
          :highlight="highlightParagraph"
        />

        <div class="text-center py-8 space-x-4">
          <n-button :disabled="!prevChapter" data-testid="reader-prev" @click.stop="goPrevChapter">上一章</n-button>
          <n-button data-testid="reader-comments" @click.stop="openComments">留言</n-button>
          <n-button type="primary" :disabled="!nextChapter" data-testid="reader-next" @click.stop="goNextChapter">
            {{ nextChapter ? '下一章' : '已是最後一章' }}
          </n-button>
        </div>
      </template>
      <div v-else-if="error && !loading" class="text-center text-gray-500 py-24" data-testid="reader-error">
        {{ loadErrorText }}
      </div>
    </n-spin>

    <ReaderToolbar
      :visible="showToolbar"
      :has-prev="!!prevChapter"
      :has-next="!!nextChapter"
      :bookmarked="chapterBookmarked"
      @prev="goPrevChapter"
      @next="goNextChapter"
      @open-settings="showSettings = true"
      @open-chapter-list="showChapterList = true"
      @open-bookmarks="openBookmarks"
      @open-comments="openComments"
      @translate="showTranslate = true"
    />

    <n-drawer v-model:show="showSettings" placement="right" :width="380">
      <n-drawer-content title="閱讀設定" closable>
        <ReaderSettingsForm />
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showChapterList" placement="left" :width="300">
      <n-drawer-content title="章節目錄">
        <div class="space-y-1">
          <div
            v-for="ch in chapterList"
            :key="ch.id"
            class="px-3 py-2 rounded cursor-pointer text-sm"
            :class="ch.id === chapter?.id ? 'bg-blue-500 text-white' : 'hover:bg-gray-100'"
            @click="navigateToChapter(ch.id)"
          >
            {{ chapterLabel(ch.chapter_number, ch.title) }}
          </div>
        </div>
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showBookmarks" placement="right" :width="360">
      <n-drawer-content title="書籤" closable>
        <div v-if="isLoggedIn" class="space-y-3 mb-4">
          <n-input
            v-model:value="bookmarkNote"
            type="textarea"
            :rows="2"
            maxlength="500"
            placeholder="備註（選填）"
            data-testid="bookmark-note"
          />
          <n-button type="primary" block :loading="addingBookmark" data-testid="bookmark-add" @click="addBookmark">
            在目前段落（第 {{ currentParagraph + 1 }} 段）加入書籤
          </n-button>
        </div>
        <n-alert v-else type="info" :show-icon="false" class="mb-4">
          <NuxtLink :to="`/login?redirect=${encodeURIComponent(route.fullPath)}`" class="text-primary">登入</NuxtLink>後即可使用書籤
        </n-alert>
        <BookmarkList
          :bookmarks="novelBookmarks"
          empty-text="這本小說還沒有書籤"
          @open="jumpToBookmark"
          @remove="removeBookmark"
        />
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showComments" placement="right" :width="440">
      <n-drawer-content title="本章留言" closable>
        <ChapterComments v-if="chapter && commentsMounted" :chapter-id="chapter.id" :current-paragraph="currentParagraph" />
        <div v-if="offline" class="text-sm text-gray-400">離線時無法載入留言。</div>
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showTranslate" placement="right" :width="320">
      <n-drawer-content title="翻譯" closable>
        <div class="space-y-3">
          <n-radio-group v-model:value="targetLang" name="translate-lang">
            <div class="flex flex-col gap-2">
              <n-radio v-for="opt in langOptions" :key="opt.value" :value="opt.value" :label="opt.label" :data-testid="`translate-lang-${opt.value}`" />
            </div>
          </n-radio-group>
          <n-alert v-if="translateError" type="warning" :show-icon="false" data-testid="translate-error">
            {{ translateError }}
          </n-alert>
          <n-button type="primary" block :loading="translating" data-testid="translate-submit" @click="handleTranslate">
            翻譯本章
          </n-button>
        </div>
      </n-drawer-content>
    </n-drawer>
  </div>
</template>

<script setup lang="ts">
import {
  NSpin, NButton, NDrawer, NDrawerContent, NRadioGroup, NRadio, NCard, NInput, NAlert, useMessage,
} from 'naive-ui'
import { useThrottleFn, useDebounceFn, useEventListener } from '@vueuse/core'
import type { LocalBookmark } from '~/utils/localDb'

definePageMeta({ layout: 'reader' })

const PROGRESS_SAVE_DELAY_MS = 8000

const route = useRoute()
const router = useRouter()
const message = useMessage()
const authStore = useAuthStore()
const isLoggedIn = computed(() => authStore.isLoggedIn)
const chapterId = computed(() => route.params.chapterId as string)

const {
  chapter, chapterList, loading, error, offline, settings, prevChapter, nextChapter, timer,
  goNextChapter, goPrevChapter, saveProgress,
} = useReader(chapterId)
const { translating, translateChapter } = useTranslation()
const bookmarks = useBookmarks()

const showToolbar = ref(false)
const showSettings = ref(false)
const showChapterList = ref(false)
const showTranslate = ref(false)
const showBookmarks = ref(false)
const showComments = ref(false)
const commentsMounted = ref(false)
const translatedContent = ref<string | null>(null)
const translatedTitle = ref<string | null>(null)
const translateError = ref('')
const targetLang = ref<'zh-TW' | 'zh-CN' | 'en'>('zh-CN')
const novelTitle = ref('')

const currentParagraph = ref(0)
const scrollOffset = ref(0)
const highlightParagraph = ref<number | null>(null)

const novelBookmarks = ref<LocalBookmark[]>([])
const bookmarkNote = ref('')
const addingBookmark = ref(false)
const chapterBookmarked = computed(() => novelBookmarks.value.some(b => b.chapter_id === chapter.value?.id))

useHead({ title: computed(() => chapter.value ? `${chapter.value.title} — 閱讀` : '閱讀中...') })

const displayContent = computed(() => translatedContent.value || chapter.value?.content || '')

const loadErrorText = computed(() => {
  const status = statusOf(error.value)
  if (status === 404) return '找不到這個章節，可能已被下架。'
  return '無法載入章節，且此章節沒有離線快取。'
})

const langOptions: { label: string, value: 'zh-TW' | 'zh-CN' | 'en' }[] = [
  { label: '簡體中文', value: 'zh-CN' },
  { label: '繁體中文', value: 'zh-TW' },
  { label: 'English', value: 'en' },
]

// ------------------------------------------------------------- position

function paragraphElements(): HTMLElement[] {
  return Array.from(document.querySelectorAll<HTMLElement>('[data-p]'))
}

/** The first paragraph whose bottom edge is below the top of the viewport. */
function measurePosition() {
  const els = paragraphElements()
  const top = 72
  const hit = els.find(el => el.getBoundingClientRect().bottom > top)
  currentParagraph.value = hit ? Number(hit.dataset.p) : Math.max(0, els.length - 1)
  const max = document.documentElement.scrollHeight - window.innerHeight
  scrollOffset.value = max > 0 ? Math.min(1, window.scrollY / max) : 1
}

function position() {
  return { paragraphIndex: currentParagraph.value, scrollOffset: scrollOffset.value }
}

const saveProgressSoon = useDebounceFn(() => saveProgress(position()), PROGRESS_SAVE_DELAY_MS)

const onScroll = useThrottleFn(() => {
  timer?.activity()
  measurePosition()
  void saveProgressSoon()
}, 200)

function scrollToParagraph(index: number, highlight = true) {
  const el = document.querySelector<HTMLElement>(`[data-p="${index}"]`)
  if (!el) return
  el.scrollIntoView({ block: 'start' })
  window.scrollBy(0, -72)
  currentParagraph.value = index
  if (highlight) {
    highlightParagraph.value = index
    setTimeout(() => {
      if (highlightParagraph.value === index) highlightParagraph.value = null
    }, 2000)
  }
}

if (import.meta.client) {
  useEventListener(window, 'scroll', onScroll, { passive: true })
  for (const type of ['keydown', 'pointerdown', 'wheel', 'touchstart'] as const) {
    useEventListener(window, type, () => timer?.activity(), { passive: true })
  }
  useEventListener(document, 'visibilitychange', () => {
    if (document.visibilityState === 'hidden') {
      timer?.pause()
      void saveProgress(position())
    }
    else {
      timer?.resume()
    }
  })
  useEventListener(window, 'keydown', (e: KeyboardEvent) => {
    const target = e.target as HTMLElement | null
    if (target?.closest('input, textarea, [contenteditable]')) return
    if (e.key === 'ArrowRight') goNextChapter()
    else if (e.key === 'ArrowLeft') goPrevChapter()
  })
}

onBeforeUnmount(() => {
  void saveProgress(position())
})

// When a chapter has loaded: restore the requested paragraph and report progress.
watch(() => chapter.value?.id, async (id) => {
  if (!id || !chapter.value) return
  translatedContent.value = null
  translatedTitle.value = null
  await nextTick()
  const p = Number(route.query.p)
  if (Number.isInteger(p) && p > 0) scrollToParagraph(p)
  else window.scrollTo(0, 0)
  measurePosition()
  void saveProgress(position())
  void loadNovelBookmarks()
  if (!novelTitle.value) {
    apiFetch<{ data: { title: string } }>(`/novels/${chapter.value.novel_id}`)
      .then((res) => { novelTitle.value = res.data.title })
      .catch(() => {})
  }
})

// ----------------------------------------------------- page mode, toolbar

function onContentClick(e: MouseEvent) {
  if (settings.value.readingMode !== 'page') {
    showToolbar.value = !showToolbar.value
    return
  }
  const x = e.clientX / window.innerWidth
  if (x < 1 / 3) pageBy(-1)
  else if (x > 2 / 3) pageBy(1)
  else showToolbar.value = !showToolbar.value
}

function pageBy(direction: 1 | -1) {
  const atBottom = window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 4
  if (direction === 1 && atBottom) {
    if (settings.value.autoChapter && nextChapter.value) goNextChapter()
    return
  }
  if (direction === -1 && window.scrollY <= 0) {
    if (settings.value.autoChapter && prevChapter.value) goPrevChapter()
    return
  }
  window.scrollBy({ top: direction * (window.innerHeight - 80) })
}

// Keep the screen on while reading when the browser supports it.
let wakeLock: { release: () => Promise<void> } | null = null
async function updateWakeLock() {
  const nav = navigator as Navigator & { wakeLock?: { request: (type: 'screen') => Promise<{ release: () => Promise<void> }> } }
  if (settings.value.keepScreenOn && document.visibilityState === 'visible' && nav.wakeLock && !wakeLock) {
    try {
      wakeLock = await nav.wakeLock.request('screen')
    }
    catch {}
  }
  else if (!settings.value.keepScreenOn && wakeLock) {
    await wakeLock.release().catch(() => {})
    wakeLock = null
  }
}
onMounted(() => void updateWakeLock())
watch(() => settings.value.keepScreenOn, () => void updateWakeLock())
if (import.meta.client) {
  useEventListener(document, 'visibilitychange', () => {
    wakeLock = null // the browser releases it when hidden
    void updateWakeLock()
  })
}
onBeforeUnmount(() => {
  void wakeLock?.release().catch(() => {})
})

function navigateToChapter(id: string) {
  showChapterList.value = false
  router.push(`/read/${id}`)
}

// ------------------------------------------------------------- bookmarks

async function loadNovelBookmarks() {
  if (!chapter.value || !isLoggedIn.value) {
    novelBookmarks.value = []
    return
  }
  try {
    novelBookmarks.value = await bookmarks.list({ novelId: chapter.value.novel_id })
  }
  catch {
    novelBookmarks.value = []
  }
}

async function openBookmarks() {
  measurePosition()
  showBookmarks.value = true
  if (isLoggedIn.value && !offline.value) await bookmarks.refresh().catch(() => {})
  await loadNovelBookmarks()
}

async function addBookmark() {
  if (!chapter.value) return
  addingBookmark.value = true
  try {
    await bookmarks.add({
      novel_id: chapter.value.novel_id,
      chapter_id: chapter.value.id,
      chapter_title: chapter.value.title,
      paragraph_index: currentParagraph.value,
      note: bookmarkNote.value,
    })
    bookmarkNote.value = ''
    message.success('已加入書籤')
    await loadNovelBookmarks()
  }
  catch (e) {
    message.error(describeError(e, { 404: '找不到這個章節' }, '加入書籤失敗'))
  }
  finally {
    addingBookmark.value = false
  }
}

async function removeBookmark(b: LocalBookmark) {
  try {
    await bookmarks.remove(b.id)
    novelBookmarks.value = novelBookmarks.value.filter(x => x.id !== b.id)
    message.success('已刪除書籤')
  }
  catch (e) {
    message.error(describeError(e, {}, '刪除失敗'))
  }
}

function jumpToBookmark(b: LocalBookmark) {
  showBookmarks.value = false
  if (b.chapter_id === chapter.value?.id) {
    scrollToParagraph(b.paragraph_index)
    return
  }
  router.push({ path: `/read/${b.chapter_id}`, query: { p: String(b.paragraph_index) } })
}

// --------------------------------------------------------- comments, i18n

function openComments() {
  commentsMounted.value = true
  measurePosition()
  showComments.value = true
}

async function handleTranslate() {
  if (!chapter.value) return
  translateError.value = ''
  if (!isLoggedIn.value) {
    translateError.value = '請先登入才能使用翻譯功能。'
    return
  }
  try {
    const result = await translateChapter(chapter.value.id, targetLang.value)
    translatedContent.value = result.translated_content
    translatedTitle.value = result.translated_title || null
    showTranslate.value = false
  }
  catch (e) {
    translateError.value = describeError(e, {
      400: '無法翻譯成這個語言。',
      404: '找不到這個章節。',
      503: targetLang.value === 'en'
        ? '目前沒有可用的英文翻譯服務，請稍後再試，或改選繁體／簡體中文。'
        : '翻譯服務暫時無法使用，請稍後再試。',
    }, '翻譯失敗，請稍後再試。')
  }
}
</script>
