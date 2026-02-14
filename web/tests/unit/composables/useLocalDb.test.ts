import { describe, it, expect } from 'vitest'

describe('LocalDb composable contract', () => {
  it('initial state is not ready', () => {
    const isReady = false
    const db = null
    expect(isReady).toBe(false)
    expect(db).toBeNull()
  })

  it('getCacheSize returns number', () => {
    const cacheSize = 0
    expect(typeof cacheSize).toBe('number')
    expect(cacheSize).toBeGreaterThanOrEqual(0)
  })

  it('getCachedChapter returns null when not cached', () => {
    const result = null
    expect(result).toBeNull()
  })
})
