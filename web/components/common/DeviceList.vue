<template>
  <div data-testid="device-list">
    <n-spin :show="loading">
      <n-alert v-if="error && !devices.length" type="error" :show-icon="false">
        <div class="flex items-center justify-between gap-3">
          <span>{{ describeError(t, error, {}, t('devices.loadFailed')) }}</span>
          <n-button size="small" @click="reload">{{ $t('common.retry') }}</n-button>
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
                <span class="font-medium truncate" data-testid="device-name">{{ d.device_name || typeLabel(d.device_type) || $t('devices.unknown') }}</span>
                <n-tag v-if="isCurrent(d)" size="tiny" type="success" :bordered="false" data-testid="device-current">{{ $t('devices.current') }}</n-tag>
              </div>
              <div class="text-xs text-gray-400">
                {{ typeLabel(d.device_type) }} · {{ $t('devices.lastActive', { time: formatRelativeTime(d.last_active_at) }) }}
              </div>
            </div>
          </div>
          <n-popconfirm @positive-click="removeOne(d)">
            <template #trigger>
              <n-button size="small" type="error" secondary :loading="removing === d.id" data-testid="device-remove">{{ $t('devices.remove') }}</n-button>
            </template>
            {{ isCurrent(d) ? $t('devices.confirmRemoveCurrent') : $t('devices.confirmRemove') }}
          </n-popconfirm>
        </div>
      </div>
      <n-empty v-else-if="!loading" :description="$t('devices.empty')" />
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import { NAlert, NButton, NEmpty, NIcon, NPopconfirm, NSpin, NTag, useMessage } from 'naive-ui'
import { DesktopOutline, GlobeOutline, PhonePortraitOutline } from '@vicons/ionicons5'
import type { ApiDevice } from '~/types/models'

const DEVICE_TYPES = ['web', 'android', 'ios', 'windows', 'macos', 'linux']

const { t, formatRelativeTime } = useFormat()
const message = useMessage()

function typeLabel(type: string): string {
  return DEVICE_TYPES.includes(type) ? t(`devices.types.${type}`) : type
}
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
    message.success(t('devices.removed'))
  }
  catch (e) {
    message.error(describeError(t, e, { 404: t('devices.alreadyRemoved') }, t('devices.removeFailed')))
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
