import type { Chapter } from '~/types/novel'

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export function useReader(chapterId: Ref<string> | string) {
  const chapter = ref<Chapter | null>(null)
  const loading = ref(true)
  const readerStore = useReaderStore()
  const router = useRouter()

  const resolvedId = computed(() => typeof chapterId === 'string' ? chapterId : chapterId.value)

  async function loadChapter(id?: string) {
    const targetId = id || resolvedId.value
    if (!targetId) return
    loading.value = true
    try {
      const res = await $fetch<ApiResponse<Chapter>>(`/api/v1/chapters/${targetId}`)
      chapter.value = res.data
      readerStore.currentChapterId = targetId
    }
    finally {
      loading.value = false
    }
  }

  async function goNextChapter() {
    if (!chapter.value) return
    const res = await $fetch<ApiResponse<Chapter[]>>(`/api/v1/novels/${chapter.value.novel_id}/chapters`, {
      params: { order: 'asc' },
    })
    const chapters = res.data
    const idx = chapters.findIndex(c => c.id === chapter.value!.id)
    if (idx >= 0 && idx < chapters.length - 1) {
      const nextId = chapters[idx + 1].id
      router.push(`/read/${nextId}`)
    }
  }

  async function goPrevChapter() {
    if (!chapter.value) return
    const res = await $fetch<ApiResponse<Chapter[]>>(`/api/v1/novels/${chapter.value.novel_id}/chapters`, {
      params: { order: 'asc' },
    })
    const chapters = res.data
    const idx = chapters.findIndex(c => c.id === chapter.value!.id)
    if (idx > 0) {
      const prevId = chapters[idx - 1].id
      router.push(`/read/${prevId}`)
    }
  }

  async function saveProgress() {
    if (!chapter.value) return
    const authStore = useAuthStore()
    if (!authStore.isLoggedIn) return
    try {
      await $fetch(`/api/v1/bookshelf/progress`, {
        method: 'PUT',
        headers: { Authorization: `Bearer ${authStore.accessToken}` },
        body: {
          novel_id: chapter.value.novel_id,
          chapter_id: chapter.value.id,
          progress: 100,
        },
      })
    }
    catch {}
  }

  onMounted(() => loadChapter())

  return {
    chapter,
    loading,
    settings: computed(() => readerStore.settings),
    loadChapter,
    goNextChapter,
    goPrevChapter,
    saveProgress,
  }
}
