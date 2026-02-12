export function useTranslation() {
  const translating = ref(false)

  async function convertText(text: string, from: string, to: string): Promise<string> {
    // TODO: POST /api/v1/translation/convert (OpenCC zh-TW <-> zh-CN)
    return text
  }

  async function translateChapter(chapterId: string, targetLang: string) {
    // TODO: POST /api/v1/translation/chapter
  }

  async function translateText(text: string, from: string, to: string): Promise<string> {
    // TODO: POST /api/v1/translation/text
    return text
  }

  return { translating, convertText, translateChapter, translateText }
}
