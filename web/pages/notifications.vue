<template>
  <div class="max-w-3xl mx-auto space-y-4">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <h1 class="text-xl font-bold">通知</h1>
      <div class="flex items-center gap-2">
        <n-radio-group v-model:value="filter" size="small" data-testid="notification-filter">
          <n-radio-button value="all">全部</n-radio-button>
          <n-radio-button value="unread">未讀{{ store.unreadCount ? `（${store.unreadCount}）` : '' }}</n-radio-button>
        </n-radio-group>
        <n-button
          size="small"
          :disabled="!hasUnread"
          :loading="markingAll"
          data-testid="notification-read-all"
          @click="readAll"
        >
          全部標為已讀
        </n-button>
      </div>
    </div>

    <n-alert v-if="error && !items.length" type="error" :show-icon="false" data-testid="notification-error">
      <div class="flex items-center justify-between gap-3">
        <span>{{ errorText }}</span>
        <n-button size="small" @click="load">重試</n-button>
      </div>
    </n-alert>

    <n-spin :show="loading && !items.length">
      <div class="space-y-2 min-h-24" data-testid="notification-list">
        <div
          v-for="n in items"
          :key="n.id"
          class="notification-item rounded border px-4 py-3 cursor-pointer"
          :class="isUnread(n) ? 'notification-item--unread' : 'border-gray-100'"
          role="button"
          tabindex="0"
          :aria-label="`${isUnread(n) ? '未讀' : '已讀'}：${n.title}`"
          :data-unread="isUnread(n) ? 'true' : 'false'"
          data-testid="notification-item"
          @click="open(n)"
          @keydown.enter.self.prevent="open(n)"
          @keydown.space.self.prevent="open(n)"
        >
          <div class="flex items-start gap-3">
            <span class="notification-dot mt-2" :class="{ 'notification-dot--on': isUnread(n) }" aria-hidden="true" />
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 text-xs text-gray-500">
                <n-tag size="tiny" :bordered="false" :type="tagType(n)">{{ NOTIFICATION_TYPE_LABELS[n.type] ?? '通知' }}</n-tag>
                <span v-if="n.actor">{{ n.actor.nickname || n.actor.username }}</span>
                <span>{{ formatRelativeTime(n.created_at) }}</span>
              </div>
              <div class="mt-1 break-words" :class="isUnread(n) ? 'font-semibold' : ''" data-testid="notification-title">
                {{ n.title }}
              </div>
              <div
                v-if="n.body"
                class="text-sm text-gray-600 mt-1 whitespace-pre-wrap break-words"
                :class="{ 'line-clamp-2': n.type !== 'system' }"
                data-testid="notification-body"
              >
                {{ n.body }}
              </div>
            </div>
            <div class="flex items-center gap-1 flex-shrink-0" @click.stop @keydown.stop>
              <n-button v-if="isUnread(n)" text size="tiny" data-testid="notification-mark-read" @click="markOne(n)">
                標為已讀
              </n-button>
              <n-popconfirm @positive-click="removeOne(n)">
                <template #trigger>
                  <n-button text size="tiny" type="error" data-testid="notification-delete">刪除</n-button>
                </template>
                確定刪除這則通知？
              </n-popconfirm>
            </div>
          </div>
        </div>

        <n-empty
          v-if="!loading && !error && !items.length"
          :description="filter === 'unread' ? '沒有未讀通知' : '目前沒有通知'"
          class="py-12"
          data-testid="notification-empty"
        />
      </div>
    </n-spin>

    <div v-if="items.length" ref="sentinel" class="flex justify-center py-2">
      <n-button v-if="hasMore" size="small" :loading="loading" data-testid="notification-more" @click="more">
        載入更多
      </n-button>
      <span v-else-if="items.length > 5" class="text-xs text-gray-400">沒有更多通知了</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NAlert, NButton, NEmpty, NPopconfirm, NRadioButton, NRadioGroup, NSpin, NTag, useMessage } from 'naive-ui'
import { useIntersectionObserver } from '@vueuse/core'
import type { ApiNotification } from '~/types/models'
import { formatRelativeTime } from '~/utils/format'
import { isUnread, notificationTarget, NOTIFICATION_TYPE_LABELS } from '~/utils/notifications'

definePageMeta({ middleware: 'auth' })
useHead({ title: '通知 — Palimpsest' })

const message = useMessage()
const router = useRouter()
const store = useNotificationsStore()
const { items, filter, loading, error, hasMore, reload, loadMore, markRead, markAllRead, remove } = useNotifications()
const markingAll = ref(false)
const sentinel = ref<HTMLElement | null>(null)

const hasUnread = computed(() => store.unreadCount > 0 || items.value.some(isUnread))
const errorText = computed(() => describeError(error.value, {}, '無法載入通知，請稍後再試'))

function tagType(n: ApiNotification) {
  if (n.type === 'system') return 'warning'
  if (n.type === 'comment_reply') return 'success'
  return 'info'
}

async function load() {
  await reload().catch(() => {})
}

async function more() {
  try {
    await loadMore()
  }
  catch (e) {
    message.error(describeError(e, {}, '無法載入更多通知'))
  }
}

async function open(n: ApiNotification) {
  if (isUnread(n)) {
    try {
      await markRead(n)
    }
    catch (e) {
      // Still follow the link; the item stays unread.
      if (!notificationTarget(n)) {
        message.error(describeError(e, { 404: '這則通知已不存在' }, '標記已讀失敗'))
        return
      }
    }
  }
  const target = notificationTarget(n)
  if (target) await router.push(target)
}

async function markOne(n: ApiNotification) {
  try {
    await markRead(n)
  }
  catch (e) {
    message.error(describeError(e, { 404: '這則通知已不存在' }, '標記已讀失敗'))
  }
}

async function readAll() {
  markingAll.value = true
  try {
    const updated = await markAllRead()
    message.success(updated ? `已將 ${updated} 則通知標為已讀` : '所有通知都已讀')
  }
  catch (e) {
    message.error(describeError(e, {}, '操作失敗，請稍後再試'))
  }
  finally {
    markingAll.value = false
  }
}

async function removeOne(n: ApiNotification) {
  try {
    await remove(n)
    message.success('已刪除通知')
  }
  catch (e) {
    message.error(describeError(e, { 404: '這則通知已不存在' }, '刪除失敗'))
  }
}

// Infinite loading: fetch the next page when the bottom comes into view.
useIntersectionObserver(sentinel, ([entry]) => {
  if (entry?.isIntersecting && hasMore.value && !loading.value && !error.value) void more()
})

watch(filter, load)
onMounted(() => {
  void load()
  void store.refresh({ force: true })
})
</script>

<style scoped>
.notification-item {
  transition: background-color 0.2s;
}
.notification-item:hover,
.notification-item:focus-visible {
  background-color: rgba(24, 144, 255, 0.06);
}
.notification-item:focus-visible {
  outline: 2px solid #1890ff;
  outline-offset: 1px;
}
.notification-item--unread {
  border-color: rgba(24, 144, 255, 0.35);
  background-color: rgba(24, 144, 255, 0.04);
}
.notification-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  background-color: transparent;
}
.notification-dot--on {
  background-color: #1890ff;
}
</style>
