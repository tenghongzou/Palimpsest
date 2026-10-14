import type { ApiResponse } from '~/utils/api'
import type { components } from '~/types/api'

export type ChapterTranslation = components['schemas']['ChapterTranslation']

export function useTranslation() {
  const translating = ref(false)

  async function convertText(text: string, from: string, to: string): Promise<string> {
    translating.value = true
    try {
      const res = await apiFetch<ApiResponse<{ text: string }>>('/translation/convert', {
        method: 'POST',
        body: { text, from, to },
      })
      return res.data.text
    }
    finally {
      translating.value = false
    }
  }

  async function translateChapter(chapterId: string, targetLang: string): Promise<ChapterTranslation> {
    translating.value = true
    try {
      const res = await apiFetch<ApiResponse<ChapterTranslation>>('/translation/chapter', {
        method: 'POST',
        body: { chapter_id: chapterId, target_lang: targetLang },
      })
      return res.data
    }
    finally {
      translating.value = false
    }
  }

  async function translateText(text: string, from: string, to: string): Promise<string> {
    translating.value = true
    try {
      const res = await apiFetch<ApiResponse<{ text: string }>>('/translation/text', {
        method: 'POST',
        body: { text, from, to },
      })
      return res.data.text
    }
    finally {
      translating.value = false
    }
  }

  return { translating, convertText, translateChapter, translateText }
}
