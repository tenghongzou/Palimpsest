<template>
  <div data-testid="device-list">
    <n-spin :show="loading">
      <n-alert v-if="error && !devices.length" type="error" :show-icon="false">
        <div class="flex items-center justify-between gap-3">
          <span>{{ describeError(error, {}, '無法載入登入裝置') }}</span>
          <n-button size="small" @click="reload">重試</n-button>
        </div>
      </n-alert>
      <div v-else-if="devices.length" class="divide-y divide-gray-100">
        <div
          v-for="d in devices"
          :key="d.id"
          class="flex items-center justify-between gap-3 py-3"
          data-testid="device-item"
        >
          <div class="flex items-center gap-3 min-w-0">
            <n-icon :component="iconFor(d.device_type)" :size="22" class="text-gray-500 flex-shrink-0" aria-hidden="true" />
            <div class="min-w-0">
              <div class="flex items-center gap-2">
                <span class="font-medium truncate" data-testid="device-name">{{ d.device_name || DEVICE_TYPE_LABELS[d.device_type] || '未知裝置' }}</span>
                <n-tag v-if="isCurrent(d)" size="tiny" type="success" :bordered="false" data-testid="device-current">此裝置</n-tag>
              </div>
              <div class="text-xs text-gray-400">
                {{ DEVICE_TYPE_LABELS[d.device_type] ?? d.device_type }} · 最近使用 {{ formatRelativeTime(d.last_active_at) }}
              </div>
            </div>
          </div>
          <n-popconfirm @positive-click="removeOne(d)">
            <template #trigger>
              <n-button size="small" type="error" secondary :loading="removing === d.id" data-testid="device-remove">移除</n-button>
            </template>
            {{ isCurrent(d) ? '移除此裝置？下次開啟網站時會重新登記。' : '確定移除這個裝置？' }}
          </n-popconfirm>
        </div>
      </div>
      <n-empty v-else-if="!loading" description="沒有登入裝置" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NAlert, NButton, NEmpty, NIcon, NPopconfirm, NSpin, NTag, useMessage } from 'naive-ui'
import { DesktopOutline, GlobeOutline, PhonePortraitOutline } from '@vicons/ionicons5'
import type { ApiDevice } from '~/types/models'
import { formatRelativeTime } from '~/utils/format'

const DEVICE_TYPE_LABELS: Record<string, string> = {
  web: '網頁',
  android: 'Android',
  ios: 'iOS',
  windows: 'Windows',
  macos: 'macOS',
  linux: 'Linux',
}

const message = useMessage()
const { devices, loading, error, load, remove, isCurrent } = useDevices()
const removing = ref<string | null>(null)

function iconFor(type: string) {
  if (type === 'android' || type === 'ios') return PhonePortraitOutline
  if (type === 'web') return GlobeOutline
  return DesktopOutline
}

async function reload() {
  await load().catch(() => {})
}

async function removeOne(d: ApiDevice) {
  removing.value = d.id
  try {
    await remove(d)
    message.success('已移除裝置')
  }
  catch (e) {
    message.error(describeError(e, { 404: '這個裝置已被移除' }, '移除失敗'))
    if (statusOf(e) === 404) await reload()
  }
  finally {
    removing.value = null
  }
}

onMounted(async () => {
  // Make sure this browser is listed before showing the list.
  await ensureDeviceRegistered()
  await reload()
})
</script>
