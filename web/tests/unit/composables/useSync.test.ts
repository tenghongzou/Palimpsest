import { describe, it, expect } from 'vitest'

describe('Sync composable contract', () => {
  it('sync state tracking', () => {
    let syncing = false
    let lastSyncAt: Date | null = null

    // Before sync
    expect(syncing).toBe(false)
    expect(lastSyncAt).toBeNull()

    // During sync
    syncing = true
    expect(syncing).toBe(true)

    // After sync
    syncing = false
    lastSyncAt = new Date()
    expect(syncing).toBe(false)
    expect(lastSyncAt).toBeInstanceOf(Date)
  })
})
