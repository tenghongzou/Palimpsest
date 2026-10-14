// Unread notification count shown by the header bell.
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { apiFetch, type ApiResponse } from '~/utils/api'
import { refreshDue } from '~/utils/notifications'

export const useNotificationsStore = defineStore('notifications', () => {
  const unreadCount = ref(0)
  /** When the last refresh started (ms since epoch), for throttling. */
  const lastRefreshAt = ref<number | null>(null)
  let inflight: Promise<number> | null = null
  // Bumped by local changes (mark read, delete) so a response that was already
  // in flight does not overwrite them with a stale count.
  let generation = 0

  /**
   * Refreshes the unread count. Non-forced calls are throttled and share an
   * in-flight request. Failures keep the last known count.
   */
  function refresh(options: { force?: boolean, now?: number } = {}): Promise<number> {
    const authStore = useAuthStore()
    if (!authStore.isLoggedIn) {
      reset()
      return Promise.resolve(0)
    }
    if (inflight) return inflight
    const now = options.now ?? Date.now()
    if (!options.force && !refreshDue(lastRefreshAt.value, now)) return Promise.resolve(unreadCount.value)
    lastRefreshAt.value = now
    const started = generation
    inflight = apiFetch<ApiResponse<{ count: number }>>('/notifications/unread-count')
      .then((res) => {
        if (started === generation && authStore.isLoggedIn) unreadCount.value = Math.max(0, res.data?.count ?? 0)
        return unreadCount.value
      })
      .catch(() => unreadCount.value)
      .finally(() => {
        inflight = null
      })
    return inflight
  }

  function setCount(count: number) {
    generation++
    unreadCount.value = Math.max(0, Math.floor(count))
  }

  /** Lowers the count after notifications were read or deleted locally. */
  function decrement(by = 1) {
    setCount(unreadCount.value - by)
  }

  function reset() {
    generation++
    unreadCount.value = 0
    lastRefreshAt.value = null
  }

  return { unreadCount, lastRefreshAt, refresh, setCount, decrement, reset }
})
