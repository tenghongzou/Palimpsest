// Pure helpers for the notification center (labels, badge text, navigation).
import type { ApiNotification, NotificationType } from '~/types/models'

export const NOTIFICATION_TYPE_LABELS: Record<NotificationType, string> = {
  chapter_update: '章節更新',
  comment_reply: '留言回覆',
  system: '系統公告',
}

/** Minimum time between unread-count requests that are not forced. */
export const UNREAD_REFRESH_MIN_MS = 15_000
/** Polling interval for the unread count while the page is visible. */
export const UNREAD_POLL_MS = 60_000

/** Badge text for an unread count: nothing for 0, "99+" above 99. */
export function badgeText(count: number): string {
  if (!Number.isFinite(count) || count <= 0) return ''
  return count > 99 ? '99+' : String(Math.floor(count))
}

/** Whether a non-forced refresh may run now, given when the last one started. */
export function refreshDue(lastAt: number | null, now: number, minInterval = UNREAD_REFRESH_MIN_MS): boolean {
  return lastAt === null || now - lastAt >= minInterval
}

export function isUnread(n: Pick<ApiNotification, 'read_at'>): boolean {
  return !n.read_at
}

export interface NotificationRoute {
  path: string
  query?: Record<string, string>
}

/**
 * Where clicking a notification leads, or null when it only gets marked read
 * (system announcements, or links to content the notification does not name).
 *
 * - `chapter_update` opens the reader at the chapter.
 * - `comment_reply` opens the reader with the comments panel on the thread
 *   (`comment_id` is the thread's top-level comment).
 */
export function notificationTarget(n: Pick<ApiNotification, 'type' | 'chapter_id' | 'comment_id' | 'novel_id'>): NotificationRoute | null {
  switch (n.type) {
    case 'chapter_update':
      if (n.chapter_id) return { path: `/read/${n.chapter_id}` }
      return n.novel_id ? { path: `/novel/${n.novel_id}` } : null
    case 'comment_reply':
      if (n.chapter_id) {
        return n.comment_id
          ? { path: `/read/${n.chapter_id}`, query: { comment: n.comment_id } }
          : { path: `/read/${n.chapter_id}`, query: { comments: '1' } }
      }
      return n.novel_id ? { path: `/novel/${n.novel_id}` } : null
    default:
      return null
  }
}

/** Merges a fetched page into a list, skipping items already shown (pages shift after deletes). */
export function mergeById<T extends { id: string }>(current: T[], incoming: T[]): T[] {
  const seen = new Set(current.map(i => i.id))
  return [...current, ...incoming.filter(i => !seen.has(i.id))]
}
