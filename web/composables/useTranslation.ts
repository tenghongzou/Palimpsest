interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export function useTranslation() {
  const translating = ref(false)
  const authStore = useAuthStore()

  function authHeaders() {
    return { Authorization: `Bearer ${authStore.accessToken}` }
  }

  async function convertText(text: string, from: string, to: string): Promise<string> {
    translating.value = true
    try {
      const res = await $fetch<ApiResponse<{ text: string }>>('/api/v1/translation/convert', {
        method: 'POST',
        headers: authHeaders(),
        body: { text, from, to },
      })
      return res.data.text
    }
    finally {
      translating.value = false
    }
  }

  async function translateChapter(chapterId: string, targetLang: string): Promise<string> {
    translating.value = true
    try {
      const res = await $fetch<ApiResponse<{ content: string }>>('/api/v1/translation/chapter', {
        method: 'POST',
        headers: authHeaders(),
        body: { chapter_id: chapterId, target_language: targetLang },
      })
      return res.data.content
    }
    finally {
      translating.value = false
    }
  }

  async function translateText(text: string, from: string, to: string): Promise<string> {
    translating.value = true
    try {
      const res = await $fetch<ApiResponse<{ text: string }>>('/api/v1/translation/text', {
        method: 'POST',
        headers: authHeaders(),
        body: { text, source_language: from, target_language: to },
      })
      return res.data.text
    }
    finally {
      translating.value = false
    }
  }

  return { translating, convertText, translateChapter, translateText }
}
