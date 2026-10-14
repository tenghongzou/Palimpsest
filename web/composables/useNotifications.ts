// The notification center list: filter, paging, mark read and delete.
import type { ApiResponse, Paginated, Pagination } from '~/utils/api'
import type { ApiNotification } from '~/types/models'
import { isUnread, mergeById } from '~/utils/notifications'

export type NotificationFilter = 'all' | 'unread'

const PAGE_SIZE = 20

export function useNotifications() {
  const store = useNotificationsStore()
  const items = ref<ApiNotification[]>([])
  const pagination = ref<Pagination>({ page: 0, page_size: PAGE_SIZE, total: 0, total_pages: 0 })
  const filter = ref<NotificationFilter>('all')
  const loading = ref(false)
  const error = ref<unknown>(null)
  // Ignores responses for a filter that is no longer selected.
  let requestId = 0

  const hasMore = computed(() => pagination.value.page < pagination.value.total_pages)

  async function fetchPage(page: number) {
    const id = ++requestId
    loading.value = true
    error.value = null
    try {
      const res = await apiFetch<ApiResponse<Paginated<ApiNotification>>>('/notifications', {
        params: { page, page_size: PAGE_SIZE, ...(filter.value === 'unread' ? { unread_only: true } : {}) },
      })
      if (id !== requestId) return
      items.value = page === 1 ? res.data.items : mergeById(items.value, res.data.items)
      pagination.value = res.data.pagination
    }
    catch (e) {
      if (id === requestId) error.value = e
      throw e
    }
    finally {
      if (id === requestId) loading.value = false
    }
  }

  /** Loads the first page again (e.g. after switching the filter). */
  function reload() {
    return fetchPage(1)
  }

  async function loadMore() {
    if (loading.value || !hasMore.value) return
    await fetchPage(pagination.value.page + 1)
  }

  async function markRead(n: ApiNotification) {
    if (!isUnread(n)) return
    await apiFetch(`/notifications/${n.id}/read`, { method: 'PUT' })
    n.read_at = new Date().toISOString()
    store.decrement()
  }

  async function markAllRead(): Promise<number> {
    const res = await apiFetch<ApiResponse<{ updated: number }>>('/notifications/read-all', { method: 'PUT' })
    const now = new Date().toISOString()
    for (const n of items.value) if (!n.read_at) n.read_at = now
    store.setCount(0)
    return res.data?.updated ?? 0
  }

  async function remove(n: ApiNotification) {
    await apiFetch(`/notifications/${n.id}`, { method: 'DELETE' })
    items.value = items.value.filter(i => i.id !== n.id)
    pagination.value.total = Math.max(0, pagination.value.total - 1)
    if (isUnread(n)) store.decrement()
  }

  return { items, pagination, filter, loading, error, hasMore, reload, loadMore, markRead, markAllRead, remove }
}
