import type { Novel } from '~/types/novel'

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

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
  const authStore = useAuthStore()

  function authHeaders() {
    return { Authorization: `Bearer ${authStore.accessToken}` }
  }

  async function fetchBookshelf(sortBy: 'recent' | 'added' | 'title' = 'recent') {
    loading.value = true
    try {
      const res = await $fetch<ApiResponse<BookshelfItem[]>>('/api/v1/bookshelf', {
        headers: authHeaders(),
        params: { sort: sortBy },
      })
      items.value = res.data
    }
    finally {
      loading.value = false
    }
  }

  async function addToBookshelf(novelId: string, groupName = 'default') {
    await $fetch('/api/v1/bookshelf', {
      method: 'POST',
      headers: authHeaders(),
      body: { novel_id: novelId, group_name: groupName },
    })
  }

  async function removeFromBookshelf(novelId: string) {
    await $fetch(`/api/v1/bookshelf/${novelId}`, {
      method: 'DELETE',
      headers: authHeaders(),
    })
    items.value = items.value.filter(item => item.novel_id !== novelId)
  }

  return { items, loading, fetchBookshelf, addToBookshelf, removeFromBookshelf }
}
