// Data sync between local SQLite and server
export function useSync() {
  const syncing = ref(false)
  const lastSyncAt = ref<Date | null>(null)

  async function syncAll() {
    syncing.value = true
    try {
      // 1. Upload pending sync queue items
      // 2. Pull latest reading progress
      // 3. Pull bookshelf changes
      // 4. Pull bookmark changes
      lastSyncAt.value = new Date()
    } finally {
      syncing.value = false
    }
  }

  return { syncing, lastSyncAt, syncAll }
}
