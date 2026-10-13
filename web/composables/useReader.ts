import type { ApiResponse } from '~/utils/api'
import type { Chapter } from '~/types/novel'
import {
  cachedChapterList,
  enforceCacheLimit,
  enqueue,
  getChapter,
  saveChapter,
  saveProgress as saveLocalProgress,
} from '~/utils/localDb'

type ChapterSummary = Omit<Chapter, 'content'>

export function useReader(chapterId: Ref<string> | string) {
  const chapter = ref<Chapter | null>(null)
  const chapterList = ref<ChapterSummary[]>([])
  const loading = ref(true)
  const error = ref<unknown>(null)
  /** True when the chapter was served from the offline cache. */
  const offline = ref(false)
  const readerStore = useReaderStore()
  const router = useRouter()
  const { withDb, readDb } = useLocalDb()

  const resolvedId = computed(() => typeof chapterId === 'string' ? chapterId : chapterId.value)

  async function fetchAndCache(id: string): Promise<Chapter> {
    const res = await apiFetch<ApiResponse<Chapter>>(`/chapters/${id}`)
    await withDb((db) => {
      saveChapter(db, res.data)
      enforceCacheLimit(db)
    })
    return res.data
  }

  async function loadChapterList(novelId: string) {
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

  function neighbour(offset: number): ChapterSummary | undefined {
    const idx = chapterList.value.findIndex(c => c.id === chapter.value?.id)
    return idx >= 0 ? chapterList.value[idx + offset] : undefined
  }

  /** Caches the next chapter in the background so it can be read offline. */
  async function prefetchNext() {
    const next = neighbour(1)
    if (!next || offline.value) return
    if (await readDb(db => getChapter(db, next.id))) return
    fetchAndCache(next.id).catch(() => {})
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
        chapter.value = { ...cached } as Chapter
        offline.value = true
      }
      readerStore.currentChapterId = targetId
      await loadChapterList(chapter.value.novel_id)
      void prefetchNext()
    }
    catch (err) {
      error.value = err
    }
    finally {
      loading.value = false
    }
  }

  function goNextChapter() {
    const next = neighbour(1)
    if (next) router.push(`/read/${next.id}`)
  }

  function goPrevChapter() {
    const prev = neighbour(-1)
    if (prev) router.push(`/read/${prev.id}`)
  }

  /**
   * Records reading progress locally and queues it for upload, so progress
   * made offline reaches the server once the connection is back.
   */
  async function saveProgress(scrollOffset = 1) {
    if (!chapter.value) return
    const authStore = useAuthStore()
    if (!authStore.isLoggedIn) return

    const progress = {
      novel_id: chapter.value.novel_id,
      chapter_id: chapter.value.id,
      paragraph_index: 0,
      scroll_offset: scrollOffset,
      read_at: new Date().toISOString(),
    }
    const queued = await withDb((db) => {
      saveLocalProgress(db, progress, false)
      enqueue(db, 'update', 'progress', progress.novel_id, progress)
      return true
    })
    if (queued) {
      await useSync().pushPending()
      return
    }
    // No local database available: send directly.
    try {
      await apiFetch(`/reading-progress/${progress.novel_id}`, { method: 'PUT', body: progress })
    }
    catch {}
  }

  onMounted(() => loadChapter())

  return {
    chapter,
    chapterList,
    loading,
    error,
    offline,
    settings: computed(() => readerStore.settings),
    loadChapter,
    goNextChapter,
    goPrevChapter,
    saveProgress,
  }
}
