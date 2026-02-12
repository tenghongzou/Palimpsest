// sql.js (WebAssembly SQLite) for offline reading support
export function useLocalDb() {
  const db = ref<any | null>(null)
  const isReady = ref(false)

  async function init() {
    // TODO: initialize sql.js, run migrations from shared/sqlite-schema
    isReady.value = true
  }

  async function cacheChapter(chapter: any) {
    // TODO: INSERT OR REPLACE into local_chapters
  }

  async function getCachedChapter(chapterId: string) {
    // TODO: SELECT from local_chapters
    return null
  }

  async function getCacheSize(): Promise<number> {
    // TODO: query local_meta for cache_size_bytes
    return 0
  }

  async function clearCache() {
    // TODO: DELETE from local_chapters, update local_meta
  }

  return { db, isReady, init, cacheChapter, getCachedChapter, getCacheSize, clearCache }
}
