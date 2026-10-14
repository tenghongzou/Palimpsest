import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { computed, ref, toValue } from 'vue'

const apiFetch = vi.fn()
vi.mock('~/utils/api', () => ({ apiFetch: (...args: unknown[]) => apiFetch(...args) }))

const { useNotificationsStore } = await import('~/stores/notifications')
const { useNotifications } = await import('~/composables/useNotifications')
const { optimisticUpdate } = await import('~/composables/useBookshelf')
const { useParagraphCounts } = await import('~/composables/useCommunity')

const auth = { isLoggedIn: true }

function deferred<T>() {
  let resolve!: (v: T) => void
  const promise = new Promise<T>((r) => { resolve = r })
  return { promise, resolve }
}

beforeEach(() => {
  setActivePinia(createPinia())
  apiFetch.mockReset()
  auth.isLoggedIn = true
  // Nuxt auto-imports used by the store and composables.
  vi.stubGlobal('useAuthStore', () => auth)
  vi.stubGlobal('useNotificationsStore', useNotificationsStore)
  vi.stubGlobal('apiFetch', (...args: unknown[]) => apiFetch(...args))
  vi.stubGlobal('ref', ref)
  vi.stubGlobal('computed', computed)
  vi.stubGlobal('toValue', toValue)
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('notifications store (unread count)', () => {
  it('loads the unread count', async () => {
    apiFetch.mockResolvedValueOnce({ data: { count: 4 } })
    const store = useNotificationsStore()
    expect(await store.refresh({ force: true })).toBe(4)
    expect(store.unreadCount).toBe(4)
    expect(apiFetch).toHaveBeenCalledWith('/notifications/unread-count')
  })

  it('throttles non-forced refreshes but not forced ones', async () => {
    apiFetch.mockResolvedValue({ data: { count: 1 } })
    const store = useNotificationsStore()
    await store.refresh({ now: 1_000 })
    await store.refresh({ now: 5_000 })
    expect(apiFetch).toHaveBeenCalledTimes(1)
    await store.refresh({ now: 5_000, force: true })
    expect(apiFetch).toHaveBeenCalledTimes(2)
    await store.refresh({ now: 30_000 })
    expect(apiFetch).toHaveBeenCalledTimes(3)
  })

  it('shares an in-flight request', async () => {
    const d = deferred<{ data: { count: number } }>()
    apiFetch.mockReturnValueOnce(d.promise)
    const store = useNotificationsStore()
    const a = store.refresh({ force: true })
    const b = store.refresh({ force: true })
    d.resolve({ data: { count: 2 } })
    expect(await a).toBe(2)
    expect(await b).toBe(2)
    expect(apiFetch).toHaveBeenCalledTimes(1)
  })

  it('keeps the last count when the request fails', async () => {
    const store = useNotificationsStore()
    store.setCount(3)
    apiFetch.mockRejectedValueOnce(new Error('offline'))
    expect(await store.refresh({ force: true })).toBe(3)
    expect(store.unreadCount).toBe(3)
  })

  it('does not let a stale response override a local change', async () => {
    const d = deferred<{ data: { count: number } }>()
    apiFetch.mockReturnValueOnce(d.promise)
    const store = useNotificationsStore()
    const pending = store.refresh({ force: true })
    store.setCount(0) // e.g. "全部標為已讀" finished meanwhile
    d.resolve({ data: { count: 5 } })
    await pending
    expect(store.unreadCount).toBe(0)
  })

  it('is zero and makes no request when logged out', async () => {
    auth.isLoggedIn = false
    const store = useNotificationsStore()
    store.setCount(7)
    expect(await store.refresh({ force: true })).toBe(0)
    expect(store.unreadCount).toBe(0)
    expect(apiFetch).not.toHaveBeenCalled()
  })

  it('never goes below zero', () => {
    const store = useNotificationsStore()
    store.setCount(1)
    store.decrement()
    store.decrement()
    expect(store.unreadCount).toBe(0)
  })
})

describe('useNotifications', () => {
  const n = (id: string, read = false) => ({
    id,
    type: 'system' as const,
    title: `t${id}`,
    read_at: read ? '2026-10-14T00:00:00Z' : null,
    created_at: '2026-10-14T00:00:00Z',
  })
  const page = (items: ReturnType<typeof n>[], p: number, totalPages: number) => ({
    data: { items, pagination: { page: p, page_size: 20, total: totalPages * 20, total_pages: totalPages } },
  })

  it('loads pages, filters unread and merges without duplicates', async () => {
    const list = useNotifications()
    apiFetch.mockResolvedValueOnce(page([n('1'), n('2')], 1, 2))
    await list.reload()
    expect(apiFetch.mock.calls[0][1].params).toEqual({ page: 1, page_size: 20 })
    expect(list.hasMore.value).toBe(true)

    apiFetch.mockResolvedValueOnce(page([n('2'), n('3')], 2, 2))
    await list.loadMore()
    expect(list.items.value.map(i => i.id)).toEqual(['1', '2', '3'])
    expect(list.hasMore.value).toBe(false)

    list.filter.value = 'unread'
    apiFetch.mockResolvedValueOnce(page([n('3')], 1, 1))
    await list.reload()
    expect(apiFetch.mock.calls[2][1].params).toEqual({ page: 1, page_size: 20, unread_only: true })
    expect(list.items.value.map(i => i.id)).toEqual(['3'])
  })

  it('updates the unread count when reading and deleting', async () => {
    const store = useNotificationsStore()
    store.setCount(3)
    const list = useNotifications()
    apiFetch.mockResolvedValueOnce(page([n('1'), n('2'), n('3', true)], 1, 1))
    await list.reload()

    apiFetch.mockResolvedValueOnce({})
    await list.markRead(list.items.value[0])
    expect(apiFetch).toHaveBeenLastCalledWith('/notifications/1/read', { method: 'PUT' })
    expect(list.items.value[0].read_at).not.toBeNull()
    expect(store.unreadCount).toBe(2)

    // Already read: no request.
    await list.markRead(list.items.value[0])
    expect(apiFetch).toHaveBeenCalledTimes(2)

    apiFetch.mockResolvedValueOnce({})
    await list.remove(list.items.value[1])
    expect(apiFetch).toHaveBeenLastCalledWith('/notifications/2', { method: 'DELETE' })
    expect(store.unreadCount).toBe(1)

    apiFetch.mockResolvedValueOnce({})
    await list.remove(list.items.value[1]) // the read one
    expect(store.unreadCount).toBe(1)
    expect(list.items.value.map(i => i.id)).toEqual(['1'])

    apiFetch.mockResolvedValueOnce({ data: { updated: 1 } })
    expect(await list.markAllRead()).toBe(1)
    expect(store.unreadCount).toBe(0)
  })

  it('keeps the count when marking read fails', async () => {
    const store = useNotificationsStore()
    store.setCount(1)
    const list = useNotifications()
    apiFetch.mockResolvedValueOnce(page([n('1')], 1, 1))
    await list.reload()
    apiFetch.mockRejectedValueOnce(new Error('500'))
    await expect(list.markRead(list.items.value[0])).rejects.toThrow()
    expect(list.items.value[0].read_at).toBeNull()
    expect(store.unreadCount).toBe(1)
  })
})

describe('optimisticUpdate (bookshelf notifications toggle)', () => {
  it('keeps the new value on success', async () => {
    const item = { is_notified: true }
    await optimisticUpdate(item, 'is_notified', false, async () => {
      expect(item.is_notified).toBe(false) // applied before the request finishes
    })
    expect(item.is_notified).toBe(false)
  })

  it('rolls back and rethrows on failure', async () => {
    const item = { is_notified: true }
    await expect(optimisticUpdate(item, 'is_notified', false, async () => {
      throw new Error('boom')
    })).rejects.toThrow('boom')
    expect(item.is_notified).toBe(true)
  })
})

describe('useParagraphCounts', () => {
  it('loads counts within the chapter and hides them on failure', async () => {
    const chapterId = ref('c1')
    const counts = useParagraphCounts(chapterId)
    expect(counts.available.value).toBe(false)

    apiFetch.mockResolvedValueOnce({ data: [{ paragraph_index: 0, count: 2 }, { paragraph_index: 7, count: 1 }] })
    await counts.load(3)
    expect(apiFetch).toHaveBeenLastCalledWith('/chapters/c1/comments/paragraph-counts')
    expect(counts.counts.value).toEqual({ 0: 2 })
    expect(counts.available.value).toBe(true)

    apiFetch.mockRejectedValueOnce(new Error('offline'))
    await counts.load(3)
    expect(counts.counts.value).toEqual({})
    expect(counts.available.value).toBe(false)
  })

  it('ignores a response for a previous chapter', async () => {
    const chapterId = ref('c1')
    const counts = useParagraphCounts(chapterId)
    const slow = deferred<{ data: { paragraph_index: number, count: number }[] }>()
    apiFetch.mockReturnValueOnce(slow.promise)
    const first = counts.load()
    chapterId.value = 'c2'
    apiFetch.mockResolvedValueOnce({ data: [{ paragraph_index: 1, count: 1 }] })
    await counts.load()
    slow.resolve({ data: [{ paragraph_index: 0, count: 9 }] })
    await first
    expect(counts.counts.value).toEqual({ 1: 1 })
  })
})
