export function useNovel(novelId: string) {
  const novel = ref<any | null>(null)
  const chapters = ref<any[]>([])
  const loading = ref(true)

  async function fetchNovel() {
    // TODO: GET /api/v1/novels/:id
    loading.value = false
  }

  async function fetchChapters(order: 'asc' | 'desc' = 'asc') {
    // TODO: GET /api/v1/novels/:id/chapters
  }

  onMounted(() => fetchNovel())

  return { novel, chapters, loading, fetchNovel, fetchChapters }
}
