export function useReader(chapterId: string) {
  const chapter = ref<any | null>(null)
  const loading = ref(true)
  const readerStore = useReaderStore()

  async function loadChapter() {
    // TODO: fetch chapter content, check local cache first
    loading.value = false
  }

  function goNextChapter() {
    // TODO: navigate to next chapter
  }

  function goPrevChapter() {
    // TODO: navigate to previous chapter
  }

  function saveProgress() {
    // TODO: save reading progress locally and sync to server
  }

  onMounted(() => loadChapter())

  return { chapter, loading, settings: readerStore.settings, goNextChapter, goPrevChapter, saveProgress }
}
