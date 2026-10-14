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
            <NuxtLink v-if="chapter" :to="`/novel/${chapter.novel_id}`" class="text-sm truncate no-underline" style="color: inherit" data-testid="reader-back">
              ‹ {{ novelTitle || $t('reader.backToNovel') }}
            </NuxtLink>
            <span class="text-xs text-gray-500 truncate">{{ chapter?.title }}</span>
          </div>
        </n-card>
      </div>
    </div>

    <n-spin :show="loading" class="min-h-screen">
      <template v-if="chapter">
        <div v-if="offline" class="text-center text-xs text-gray-500 pt-2" data-testid="offline-notice">
          {{ $t('reader.offlineNotice') }}
        </div>
        <div v-if="translatedContent" class="text-center text-xs text-gray-500 pt-2">
          {{ $t('reader.translate.showing') }}
          <n-button text size="tiny" type="primary" @click.stop="translatedContent = null">{{ $t('reader.translate.showOriginal') }}</n-button>
        </div>
        <ReaderContent
          :content="displayContent"
          :title="translatedTitle || chapter.title"
          :settings="settings"
          :highlight="highlightParagraph"
          :active-paragraph="showParagraphComments ? paragraphTarget : null"
          :comment-counts="markerCounts"
          @open-paragraph-comments="openParagraphComments"
        />

        <div class="text-center py-8 space-x-4">
          <n-button :disabled="!prevChapter" data-testid="reader-prev" @click.stop="goPrevChapter">{{ $t('reader.prevChapter') }}</n-button>
          <n-button data-testid="reader-comments" @click.stop="openComments">{{ $t('reader.toolbar.comments') }}</n-button>
          <n-button type="primary" :disabled="!nextChapter" data-testid="reader-next" @click.stop="goNextChapter">
            {{ nextChapter ? $t('reader.nextChapter') : $t('reader.lastChapter') }}
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
      <n-drawer-content :title="$t('reader.toolbar.settings')" closable>
        <ReaderSettingsForm />
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showChapterList" placement="left" :width="300">
      <n-drawer-content :title="$t('reader.chapterList')">
        <div class="space-y-1">
          <div
            v-for="ch in chapterList"
            :key="ch.id"
            class="px-3 py-2 rounded cursor-pointer text-sm"
            :class="ch.id === chapter?.id ? 'bg-blue-500 text-white' : 'hover:bg-gray-500/15'"
            @click="navigateToChapter(ch.id)"
          >
            {{ chapterLabel(ch.chapter_number, ch.title) }}
          </div>
        </div>
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showBookmarks" placement="right" :width="360">
      <n-drawer-content :title="$t('reader.toolbar.bookmarks')" closable>
        <div v-if="isLoggedIn" class="space-y-3 mb-4">
          <n-input
            v-model:value="bookmarkNote"
            type="textarea"
            :rows="2"
            maxlength="500"
            :placeholder="$t('reader.bookmarks.notePlaceholder')"
            data-testid="bookmark-note"
          />
          <n-button type="primary" block :loading="addingBookmark" data-testid="bookmark-add" @click="addBookmark">
            {{ $t('reader.bookmarks.addHere', { n: currentParagraph + 1 }) }}
          </n-button>
        </div>
        <n-alert v-else type="info" :show-icon="false" class="mb-4">
          <i18n-t keypath="reader.bookmarks.loginToUse" tag="span" scope="global">
            <template #login>
              <NuxtLink :to="`/login?redirect=${encodeURIComponent(route.fullPath)}`" class="text-primary">{{ $t('common.login') }}</NuxtLink>
            </template>
          </i18n-t>
        </n-alert>
        <BookmarkList
          :bookmarks="novelBookmarks"
          :empty-text="$t('reader.bookmarks.emptyNovel')"
          @open="jumpToBookmark"
          @remove="removeBookmark"
        />
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showComments" placement="right" :width="440">
      <n-drawer-content :title="$t('reader.chapterComments')" closable>
        <ChapterComments
          v-if="chapter && commentsMounted"
          :chapter-id="chapter.id"
          :current-paragraph="currentParagraph"
          :focus-thread="focusThread"
          :paragraph-attachable="paragraphsMatch"
          @changed="refreshParagraphCounts"
        />
        <div v-if="offline" class="text-sm text-gray-400">{{ $t('reader.commentsOffline') }}</div>
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showParagraphComments" placement="right" :width="440">
      <n-drawer-content :title="paragraphTarget !== null ? $t('reader.paragraph.commentsOf', { n: paragraphTarget + 1 }) : $t('reader.paragraph.comments')" closable>
        <div data-testid="paragraph-comments-drawer">
          <blockquote
            v-if="paragraphTarget !== null"
            class="paragraph-excerpt text-sm mb-4"
            data-testid="paragraph-excerpt"
          >
            {{ paragraphExcerpt(displayParagraphs[paragraphTarget], 120) }}
          </blockquote>
          <ChapterComments
            v-if="chapter && paragraphTarget !== null"
            :chapter-id="chapter.id"
            :current-paragraph="paragraphTarget"
            :paragraph-index="paragraphTarget"
            :focus-thread="paragraphFocusThread"
            @changed="refreshParagraphCounts"
          />
        </div>
      </n-drawer-content>
    </n-drawer>

    <n-drawer v-model:show="showTranslate" placement="right" :width="320">
      <n-drawer-content :title="$t('reader.toolbar.translate')" closable>
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
            {{ $t('reader.translate.submit') }}
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
import { useThrottleFn, useDebounceFn, useEventListener, useOnline } from '@vueuse/core'
import type { LocalBookmark } from '~/utils/localDb'
import type { ApiComment } from '~/types/models'
import { paragraphExcerpt, paragraphsAligned, threadPanel } from '~/utils/paragraphComments'
import { splitParagraphs } from '~/utils/text'

definePageMeta({ layout: 'reader' })

const PROGRESS_SAVE_DELAY_MS = 8000

const { t, chapterLabel } = useFormat()
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

useHead({ title: () => chapter.value?.title ?? t('reader.loadingTitle') })

const displayContent = computed(() => translatedContent.value || chapter.value?.content || '')
const displayParagraphs = computed(() => splitParagraphs(displayContent.value))

// ------------------------------------------------------ paragraph comments

const online = useOnline()
const paragraphCounts = useParagraphCounts(() => chapter.value?.id)
const showParagraphComments = ref(false)
const paragraphTarget = ref<number | null>(null)
/** Thread to highlight in the chapter comments / paragraph panel (from a notification). */
const focusThread = ref<ApiComment | null>(null)
const paragraphFocusThread = ref<ApiComment | null>(null)

/** Paragraph indexes refer to the original text; a translation must split the same way. */
const paragraphsMatch = computed(() => paragraphsAligned(chapter.value?.content, translatedContent.value))

/** Counts for the paragraph markers, or null to hide them (offline, not loaded, misaligned). */
const markerCounts = computed(() => {
  if (offline.value || !online.value || !paragraphCounts.available.value || !paragraphsMatch.value) return null
  return paragraphCounts.counts.value
})

function refreshParagraphCounts() {
  if (!chapter.value || offline.value) return
  void paragraphCounts.load(splitParagraphs(chapter.value.content).length)
}

function openParagraphComments(index: number, thread: ApiComment | null = null) {
  paragraphFocusThread.value = thread
  paragraphTarget.value = index
  showParagraphComments.value = true
}

/**
 * Opens the comments on the thread containing `commentId` (a `comment_reply`
 * notification): the paragraph panel for paragraph comments, otherwise the
 * chapter comments, with the thread highlighted.
 */
async function openThread(commentId: string) {
  if (offline.value) {
    openComments()
    return
  }
  let thread: ApiComment
  try {
    thread = await fetchCommentThread(commentId)
  }
  catch (e) {
    message.info(describeError(t, e, { 404: t('reader.commentGone') }, t('reader.commentLoadFailed')))
    openComments()
    return
  }
  if (thread.chapter_id && thread.chapter_id !== chapter.value?.id) {
    openComments()
    return
  }
  const panel = threadPanel(thread, displayParagraphs.value.length, paragraphsMatch.value)
  if (panel.kind === 'paragraph') {
    scrollToParagraph(panel.index)
    openParagraphComments(panel.index, thread)
  }
  else {
    focusThread.value = thread
    openComments()
  }
}

watch(online, (isOnline) => {
  if (isOnline && !paragraphCounts.available.value) refreshParagraphCounts()
})

const loadErrorText = computed(() => {
  const status = statusOf(error.value)
  if (status === 404) return t('reader.notFound')
  return t('reader.loadFailedNoCache')
})

// Target languages of the content translation (independent of the UI language).
const langOptions = computed(() => (['zh-CN', 'zh-TW', 'en'] as const).map(value => ({ label: t(`reader.translate.langs.${value}`), value })))

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
  showParagraphComments.value = false
  paragraphTarget.value = null
  focusThread.value = null
  paragraphFocusThread.value = null
  paragraphCounts.clear()
  refreshParagraphCounts()
  await nextTick()
  const p = Number(route.query.p)
  if (Number.isInteger(p) && p > 0) scrollToParagraph(p)
  else window.scrollTo(0, 0)
  measurePosition()
  void saveProgress(position())
  void loadNovelBookmarks()
  // From a notification: open the comments, on the replied thread if given.
  const focus = route.query.comment
  if (typeof focus === 'string' && focus) {
    void openThread(focus)
  }
  else if (route.query.comments === '1') {
    openComments()
  }
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
    message.success(t('reader.bookmarks.added'))
    await loadNovelBookmarks()
  }
  catch (e) {
    message.error(describeError(t, e, { 404: t('reader.chapterNotFound') }, t('reader.bookmarks.addFailed')))
  }
  finally {
    addingBookmark.value = false
  }
}

async function removeBookmark(b: LocalBookmark) {
  try {
    await bookmarks.remove(b.id)
    novelBookmarks.value = novelBookmarks.value.filter(x => x.id !== b.id)
    message.success(t('reader.bookmarks.deleted'))
  }
  catch (e) {
    message.error(describeError(t, e, {}, t('common.deleteFailed')))
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
    translateError.value = t('reader.translate.loginRequired')
    return
  }
  try {
    const result = await translateChapter(chapter.value.id, targetLang.value)
    translatedContent.value = result.translated_content
    translatedTitle.value = result.translated_title || null
    showTranslate.value = false
  }
  catch (e) {
    translateError.value = describeError(t, e, {
      400: t('reader.translate.unsupported'),
      404: t('reader.translate.notFound'),
      503: targetLang.value === 'en'
        ? t('reader.translate.englishUnavailable')
        : t('reader.translate.unavailable'),
    }, t('reader.translate.failed'))
  }
}
</script>

<style scoped>
.paragraph-excerpt {
  margin: 0;
  padding: 8px 12px;
  border-left: 3px solid rgba(128, 128, 128, 0.45);
  background-color: rgba(128, 128, 128, 0.08);
  border-radius: 0 4px 4px 0;
  white-space: pre-wrap;
  word-break: break-word;
}
</style>
