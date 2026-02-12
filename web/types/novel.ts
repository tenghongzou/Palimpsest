export interface Novel {
  id: string
  title: string
  author_name: string
  cover_url: string
  description: string
  status: 'ongoing' | 'completed' | 'hiatus'
  language: 'zh-TW' | 'zh-CN' | 'en'
  total_words: number
  total_chapters: number
  view_count: number
  favorite_count: number
  avg_rating: number
  latest_chapter_title: string
  latest_chapter_at: string
  categories: Category[]
  tags: Tag[]
}

export interface Category {
  id: number
  name: string
  slug: string
  parent_id?: number
  children?: Category[]
}

export interface Tag {
  id: number
  name: string
}

export interface Chapter {
  id: string
  novel_id: string
  title: string
  content: string
  chapter_number: number
  word_count: number
}
