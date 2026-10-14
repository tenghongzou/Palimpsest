<template>
  <NuxtLink
    to="/notifications"
    class="notification-bell"
    :aria-label="unread ? `通知（${unread} 則未讀）` : '通知'"
    :title="unread ? `${unread} 則未讀通知` : '通知'"
    data-testid="notification-bell"
  >
    <n-badge :value="badge" :show="unread > 0" data-testid="notification-badge">
      <n-icon :component="NotificationsOutline" :size="22" aria-hidden="true" />
    </n-badge>
  </NuxtLink>
</template>

<script setup lang="ts">
import { NBadge, NIcon } from 'naive-ui'
import { NotificationsOutline } from '@vicons/ionicons5'
import { useDocumentVisibility, useEventListener, useIntervalFn } from '@vueuse/core'
import { badgeText, UNREAD_POLL_MS } from '~/utils/notifications'

// Keeps the unread count fresh while the header is shown: on mount, on route
// changes and window focus (both throttled by the store) and on a timer while
// the page is visible. Render it client-only (it starts timers).
const store = useNotificationsStore()
const route = useRoute()
const visibility = useDocumentVisibility()

const unread = computed(() => store.unreadCount)
const badge = computed(() => badgeText(store.unreadCount))

function refresh() {
  if (visibility.value === 'hidden') return
  void store.refresh()
}

onMounted(refresh)
watch(() => route.fullPath, refresh)
useEventListener('focus', refresh)
watch(visibility, v => v === 'visible' && refresh())
useIntervalFn(refresh, UNREAD_POLL_MS)
</script>

<style scoped>
.notification-bell {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  color: inherit;
  transition: background-color 0.2s;
}
.notification-bell:hover,
.notification-bell:focus-visible {
  background-color: rgba(0, 0, 0, 0.06);
}
.notification-bell:focus-visible {
  outline: 2px solid #1890ff;
  outline-offset: 1px;
}
</style>
