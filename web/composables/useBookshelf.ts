import type { ApiResponse } from '~/utils/api'
import type { Novel } from '~/types/novel'

interface BookshelfItem {
  id: string
  novel_id: string
  novel: Novel
  group_name: string
  last_read_chapter_id: string | null
  last_read_at: string | null
  created_at: string
}

export function useBookshelf() {
  const items = ref<BookshelfItem[]>([])
  const loading = ref(true)

  async function fetchBookshelf(sortBy: 'recent' | 'added' | 'title' = 'recent') {
    loading.value = true
    try {
      const res = await apiFetch<ApiResponse<BookshelfItem[]>>('/bookshelf', {
        params: { sort_by: sortBy },
      })
      items.value = res.data
    }
    finally {
      loading.value = false
    }
  }

  async function addToBookshelf(novelId: string, groupName = 'default') {
    await apiFetch('/bookshelf', {
      method: 'POST',
      body: { novel_id: novelId, group_name: groupName },
    })
  }

  async function removeFromBookshelf(novelId: string) {
    await apiFetch(`/bookshelf/${novelId}`, { method: 'DELETE' })
    items.value = items.value.filter(item => item.novel_id !== novelId)
  }

  return { items, loading, fetchBookshelf, addToBookshelf, removeFromBookshelf }
}
