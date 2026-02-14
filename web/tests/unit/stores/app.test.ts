import { describe, it, expect } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useAppStore } from '~/stores/app'

describe('App Store', () => {
  it('has correct default locale', () => {
    setActivePinia(createPinia())
    const store = useAppStore()
    expect(store.locale).toBe('zh-TW')
  })

  it('changes locale', () => {
    setActivePinia(createPinia())
    const store = useAppStore()
    store.setLocale('en')
    expect(store.locale).toBe('en')
  })

  it('has correct default state', () => {
    setActivePinia(createPinia())
    const store = useAppStore()
    expect(store.isOffline).toBe(false)
    expect(store.isSidebarOpen).toBe(false)
  })
})
