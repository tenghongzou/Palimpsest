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
  review_count?: number
  avg_rating: number
  is_published?: boolean
  is_featured?: boolean
  latest_chapter_id?: string
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

export interface ChapterRef {
  id: string
  title: string
  chapter_number: number
}

/** A chapter with links to its neighbours (GET /chapters/{id}). */
export interface ChapterDetail extends Chapter {
  prev_chapter?: ChapterRef | null
  next_chapter?: ChapterRef | null
}
