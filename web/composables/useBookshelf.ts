export function useBookshelf() {
  const items = ref<any[]>([])
  const loading = ref(true)

  async function fetchBookshelf(sortBy: 'recent' | 'added' | 'title' = 'recent') {
    // TODO: GET /api/v1/bookshelf
    loading.value = false
  }

  async function addToBookshelf(novelId: string, groupName = 'default') {
    // TODO: POST /api/v1/bookshelf
  }

  async function removeFromBookshelf(novelId: string) {
    // TODO: DELETE /api/v1/bookshelf/:novelId
  }

  return { items, loading, fetchBookshelf, addToBookshelf, removeFromBookshelf }
}
