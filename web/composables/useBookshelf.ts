import type { ApiResponse } from '~/utils/api'
import type { ApiBookshelfEntry, ApiBookshelfItemUpdate } from '~/types/models'

export type BookshelfEntry = ApiBookshelfEntry
export type BookshelfSort = 'recent' | 'added' | 'title'

export const DEFAULT_GROUP = 'default'

/** Display name of a bookshelf group. */
export function groupLabel(name: string | null | undefined): string {
  return !name || name === DEFAULT_GROUP ? '預設' : name
}

/** Distinct group names, the default group first, the rest alphabetically. */
export function bookshelfGroups(items: Pick<BookshelfEntry, 'group_name'>[]): string[] {
  const names = new Set(items.map(i => i.group_name || DEFAULT_GROUP))
  return [...names].sort((a, b) => a === DEFAULT_GROUP ? -1 : b === DEFAULT_GROUP ? 1 : a.localeCompare(b, 'zh-Hant'))
}

/** Whether new chapters of a shelved novel send notifications (on unless turned off). */
export function isNotified(item: Pick<BookshelfEntry, 'is_notified'>): boolean {
  return item.is_notified !== false
}

/**
 * Applies `value` to `item` right away, runs `save`, and restores the old
 * value if it fails (the error is rethrown).
 */
export async function optimisticUpdate<T extends object, K extends keyof T>(item: T, key: K, value: T[K], save: () => Promise<unknown>): Promise<void> {
  const previous = item[key]
  item[key] = value
  try {
    await save()
  }
  catch (e) {
    item[key] = previous
    throw e
  }
}

export function useBookshelf() {
  const items = ref<BookshelfEntry[]>([])
  const loading = ref(true)

  async function fetchBookshelf(sortBy: BookshelfSort = 'recent') {
    loading.value = true
    try {
      const res = await apiFetch<ApiResponse<BookshelfEntry[]>>('/bookshelf', {
        params: { sort_by: sortBy },
      })
      items.value = res.data
    }
    finally {
      loading.value = false
    }
  }

  async function addToBookshelf(novelId: string, groupName = DEFAULT_GROUP) {
    await apiFetch('/bookshelf', {
      method: 'POST',
      body: { novel_id: novelId, group_name: groupName },
    })
  }

  async function removeFromBookshelf(novelId: string) {
    await apiFetch(`/bookshelf/${novelId}`, { method: 'DELETE' })
    items.value = items.value.filter(item => item.novel_id !== novelId)
  }

  async function removeMany(novelIds: string[]) {
    if (!novelIds.length) return
    await apiFetch('/bookshelf/batch-remove', { method: 'POST', body: { novel_ids: novelIds } })
    const removed = new Set(novelIds)
    items.value = items.value.filter(item => !removed.has(item.novel_id))
  }

  async function moveToGroup(novelId: string, groupName: string) {
    const name = groupName.trim() || DEFAULT_GROUP
    const res = await apiFetch<ApiResponse<{ group_name: string }>>(`/bookshelf/${novelId}`, {
      method: 'PATCH',
      body: { group_name: name },
    })
    const item = items.value.find(i => i.novel_id === novelId)
    if (item) item.group_name = res.data?.group_name ?? name
  }

  /** Turns update notifications for a shelved novel on or off (optimistic, rolled back on error). */
  async function setNotified(novelId: string, on: boolean) {
    const item = items.value.find(i => i.novel_id === novelId)
    const body: ApiBookshelfItemUpdate = { is_notified: on }
    const save = () => apiFetch(`/bookshelf/${novelId}`, { method: 'PATCH', body })
    if (!item) {
      await save()
      return
    }
    await optimisticUpdate(item, 'is_notified', on, save)
  }

  return { items, loading, fetchBookshelf, addToBookshelf, removeFromBookshelf, removeMany, moveToGroup, setNotified }
}
