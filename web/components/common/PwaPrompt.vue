<template>
  <span hidden />
</template>

<script setup lang="ts">
// Service worker notices inside the layout's message provider. A new version
// waits for the user: reloading mid-chapter would lose the reading position.
import { NButton, useMessage, type MessageReactive } from 'naive-ui'
import { flushLocalDb } from '~/composables/useLocalDb'

const { t } = useI18n()
const message = useMessage()
const pwa = import.meta.client ? useNuxtApp().$pwa : undefined

let updateNotice: MessageReactive | null = null

async function reload() {
  updateNotice?.destroy()
  updateNotice = null
  // Persist the offline store (progress, bookmarks) before the page reloads.
  await flushLocalDb().catch(() => {})
  await pwa?.updateServiceWorker(true)
}

function showUpdateNotice() {
  if (updateNotice) return
  updateNotice = message.info(
    () => h('span', { 'data-testid': 'pwa-update' }, [
      `${t('pwa.updateAvailable')} `,
      h(NButton, { text: true, type: 'primary', size: 'small', onClick: reload, 'data-testid': 'pwa-reload' }, () => t('pwa.reload')),
    ]),
    { duration: 0, closable: true, onClose: () => { updateNotice = null } },
  )
}

if (pwa) {
  watch(() => pwa.needRefresh, (needRefresh) => {
    if (needRefresh) showUpdateNotice()
  }, { immediate: true })
  watch(() => pwa.offlineReady, (ready) => {
    if (ready) {
      message.success(t('pwa.offlineReady'), { duration: 3000 })
      pwa.offlineReady = false
    }
  })
}

onBeforeUnmount(() => updateNotice?.destroy())
</script>
