import type { ApiResponse } from '~/utils/api'
import type { Chapter, ChapterDetail, ChapterRef } from '~/types/novel'
import {
  cachedChapterList,
  enforceCacheLimit,
  enqueueProgress,
  getChapter,
  saveChapter,
  saveProgress as saveLocalProgress,
} from '~/utils/localDb'
import { ReadingTimer } from '~/utils/readingTimer'

type ChapterSummary = Omit<Chapter, 'content'>

/** Seconds of reading reported in one progress update at most. */
const MAX_REPORT_SECONDS = 1800

export interface ProgressPosition {
  paragraphIndex: number
  /** Fraction of the chapter scrolled, 0..1 */
  scrollOffset: number
}

export function useReader(chapterId: Ref<string> | string) {
  const chapter = ref<ChapterDetail | null>(null)
  const chapterList = ref<ChapterSummary[]>([])
  const loading = ref(true)
  const error = ref<unknown>(null)
  /** True when the chapter was served from the offline cache. */
  const offline = ref(false)
  const readerStore = useReaderStore()
  const authStore = useAuthStore()
  const router = useRouter()
  const { withDb, readDb } = useLocalDb()
  const timer = import.meta.client ? new ReadingTimer() : null

  const resolvedId = computed(() => typeof chapterId === 'string' ? chapterId : chapterId.value)

  /** countView is false for background prefetches, which are not reads. */
  async function fetchAndCache(id: string, countView = true): Promise<ChapterDetail> {
    const res = await apiFetch<ApiResponse<ChapterDetail>>(`/chapters/${id}`, countView ? {} : { params: { count_view: 'false' } })
    await withDb((db) => {
      saveChapter(db, res.data)
      enforceCacheLimit(db)
    })
    return res.data
  }

  async function loadChapterList(novelId: string) {
    if (chapterList.value.length && chapterList.value[0]?.novel_id === novelId && !offline.value) return
    try {
      const res = await apiFetch<ApiResponse<ChapterSummary[]>>(`/novels/${novelId}/chapters`, {
        params: { order: 'asc' },
      })
      chapterList.value = res.data
    }
    catch {
      chapterList.value = (await readDb(db => cachedChapterList(db, novelId))) ?? []
    }
  }

  function neighbour(offset: number): ChapterRef | undefined {
    const idx = chapterList.value.findIndex(c => c.id === chapter.value?.id)
    return idx >= 0 ? chapterList.value[idx + offset] : undefined
  }

  /** Online the chapter response links its neighbours; offline the cached list is used. */
  const prevChapter = computed<ChapterRef | null>(() => {
    const c = chapter.value
    if (c && !offline.value && c.prev_chapter !== undefined) return c.prev_chapter
    return neighbour(-1) ?? null
  })
  const nextChapter = computed<ChapterRef | null>(() => {
    const c = chapter.value
    if (c && !offline.value && c.next_chapter !== undefined) return c.next_chapter
    return neighbour(1) ?? null
  })

  /** Caches the next chapter in the background so it can be read offline. */
  async function prefetchNext() {
    const next = nextChapter.value
    if (!next || offline.value) return
    if (await readDb(db => getChapter(db, next.id))) return
    fetchAndCache(next.id, false).catch(() => {})
  }

  async function loadChapter(id?: string) {
    const targetId = id || resolvedId.value
    if (!targetId) return
    loading.value = true
    error.value = null
    try {
      try {
        chapter.value = await fetchAndCache(targetId)
        offline.value = false
      }
      catch (err) {
        const cached = await readDb(db => getChapter(db, targetId))
        if (!cached) throw err
        chapter.value = { ...cached }
        offline.value = true
      }
      readerStore.currentChapterId = targetId
      await loadChapterList(chapter.value.novel_id)
      void prefetchNext()
    }
    catch (err) {
      error.value = err
      chapter.value = null
    }
    finally {
      loading.value = false
    }
  }

  function goToChapter(ref: ChapterRef | null, query?: Record<string, string>) {
    if (ref) router.push({ path: `/read/${ref.id}`, query })
  }

  function goNextChapter() {
    goToChapter(nextChapter.value)
  }

  function goPrevChapter() {
    goToChapter(prevChapter.value)
  }

  /**
   * Records reading progress locally and queues it for upload with the
   * reading time since the previous report, so progress made offline reaches
   * the server once the connection is back.
   */
  async function saveProgress(position: ProgressPosition = { paragraphIndex: 0, scrollOffset: 0 }) {
    const current = chapter.value
    if (!current || !authStore.isLoggedIn) return

    const progress = {
      novel_id: current.novel_id,
      chapter_id: current.id,
      paragraph_index: Math.max(0, Math.trunc(position.paragraphIndex)),
      scroll_offset: Math.min(1, Math.max(0, Number(position.scrollOffset.toFixed(4)))),
      read_at: new Date().toISOString(),
      duration: timer?.take(MAX_REPORT_SECONDS) ?? 0,
    }
    const queued = await withDb((db) => {
      saveLocalProgress(db, progress, false)
      enqueueProgress(db, progress)
      return true
    })
    if (queued) {
      await useSync().pushPending()
      return
    }
    // No local database available: send directly.
    try {
      const { novel_id: novelId, ...body } = progress
      await apiFetch(`/reading-progress/${novelId}`, { method: 'PUT', body })
    }
    catch {}
  }

  onMounted(() => loadChapter())
  // Normally the page remounts per chapter; this covers a reused component.
  if (typeof chapterId !== 'string') {
    watch(chapterId, (id, old) => {
      if (id && id !== old) void loadChapter(id)
    })
  }

  return {
    chapter,
    chapterList,
    loading,
    error,
    offline,
    prevChapter,
    nextChapter,
    timer,
    settings: computed(() => readerStore.settings),
    loadChapter,
    goToChapter,
    goNextChapter,
    goPrevChapter,
    saveProgress,
  }
}
