// Bookmarks are written to the local database first and queued for upload, so
// they work offline. Without a local database they go straight to the API.
import type { ApiResponse } from '~/utils/api'
import type { ApiBookmark } from '~/types/models'
import {
  enqueue,
  listBookmarks,
  markBookmarkDeleted,
  saveBookmark,
  toIso,
  type LocalBookmark,
} from '~/utils/localDb'
import { newUuid } from '~/utils/uuid'


export interface NewBookmark {
  novel_id: string
  chapter_id: string
  chapter_title?: string | null
  paragraph_index: number
  note?: string | null
}

function fromServer(b: ApiBookmark): LocalBookmark {
  return {
    id: b.id,
    novel_id: b.novel_id,
    chapter_id: b.chapter_id,
    chapter_title: b.chapter?.title ?? null,
    paragraph_index: b.paragraph_index ?? 0,
    note: b.note ?? null,
    created_at: toIso(b.created_at),
    is_synced: 1,
  }
}

export function useBookmarks() {
  const { withDb, readDb } = useLocalDb()
  const { pushPending, syncBookmarks } = useSync()

  async function list(filter: { novelId?: string, chapterId?: string } = {}): Promise<LocalBookmark[]> {
    const local = await readDb(db => listBookmarks(db, filter))
    if (local) return local
    const res = await apiFetch<ApiResponse<ApiBookmark[]>>('/bookmarks', {
      params: filter.novelId ? { novel_id: filter.novelId } : {},
    })
    return res.data
      .map(fromServer)
      .filter(b => !filter.chapterId || b.chapter_id === filter.chapterId)
  }

  async function add(input: NewBookmark): Promise<LocalBookmark> {
    const bookmark: LocalBookmark = {
      id: newUuid(),
      novel_id: input.novel_id,
      chapter_id: input.chapter_id,
      chapter_title: input.chapter_title ?? null,
      paragraph_index: Math.max(0, Math.trunc(input.paragraph_index)),
      note: input.note?.trim() || null,
      created_at: new Date().toISOString(),
      is_synced: 0,
    }
    const payload = {
      id: bookmark.id,
      chapter_id: bookmark.chapter_id,
      paragraph_index: bookmark.paragraph_index,
      note: bookmark.note ?? undefined,
      created_at: bookmark.created_at,
    }
    const stored = await withDb((db) => {
      saveBookmark(db, bookmark, false)
      enqueue(db, 'upsert', 'bookmark', bookmark.id, payload)
      return true
    })
    if (stored) {
      void pushPending()
      return bookmark
    }
    const res = await apiFetch<ApiResponse<ApiBookmark>>('/bookmarks', { method: 'POST', body: payload })
    return fromServer(res.data)
  }

  async function remove(id: string) {
    const stored = await withDb((db) => {
      markBookmarkDeleted(db, id)
      enqueue(db, 'delete', 'bookmark', id, undefined)
      return true
    })
    if (stored) {
      void pushPending()
      return
    }
    await apiFetch(`/bookmarks/${id}`, { method: 'DELETE' })
  }

  /** Pulls the server list into the local mirror (pushing queued changes first). */
  async function refresh() {
    await syncBookmarks()
  }

  return { list, add, remove, refresh }
}
