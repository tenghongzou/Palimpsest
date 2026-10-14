import { describe, expect, it } from 'vitest'
import {
  APP_SHELL_URL,
  PERSONALIZED_HEADER,
  i18nMessagesLocale,
  i18nPrecacheUrl,
  isAppShellRoute,
  isCacheableImage,
  isCacheablePage,
  isHandledNavigation,
} from '~/service-worker/routes'
import { hasSession } from '~/server/utils/session'

const headers = (h: Record<string, string>) => ({ get: (name: string) => h[name.toLowerCase()] ?? null })

describe('service worker navigation routing', () => {
  it('handles page navigations but never the API, admin console or build assets', () => {
    for (const path of ['/', '/novel/abc', '/category/xuanhuan', '/ranking/views', '/read/c1', '/bookshelf', '/profile/settings', '/search']) {
      expect(isHandledNavigation(path), path).toBe(true)
    }
    for (const path of ['/api', '/api/v1/users/me', '/admin', '/admin/novels', '/_nuxt/entry.js', '/__nuxt_error', '/_i18n/x/en/messages.json', '/sw.js', '/workbox-123.js']) {
      expect(isHandledNavigation(path), path).toBe(false)
    }
    // Segment match: a page merely starting with "admin" is still a page.
    expect(isHandledNavigation('/administrator-guide')).toBe(true)
  })

  it('boots client-rendered routes from the app shell', () => {
    for (const path of ['/read/c1', '/bookshelf', '/notifications', '/profile', '/profile/bookmarks']) {
      expect(isAppShellRoute(path), path).toBe(true)
    }
    for (const path of ['/', '/novel/n1', '/category', '/ranking/views', '/bookshelf-tips', '/reader']) {
      expect(isAppShellRoute(path), path).toBe(false)
    }
    expect(APP_SHELL_URL).toBe('/app-shell')
  })

  it('maps locale message requests to the precached copy', () => {
    expect(i18nMessagesLocale('/_i18n/a1b2c3d4/zh-TW/messages.json')).toBe('zh-TW')
    expect(i18nMessagesLocale('/_i18n/a1b2c3d4/en/messages.json')).toBe('en')
    expect(i18nMessagesLocale('/_i18n/en/messages.json')).toBeNull()
    expect(i18nMessagesLocale('/api/v1/novels')).toBeNull()
    expect(i18nPrecacheUrl('zh-CN')).toBe('/_i18n/sw/zh-CN/messages.json')
  })
})

describe('service worker caching rules', () => {
  const origin = 'https://palimpsest.example'

  it('caches images, including covers from object storage, but not API responses', () => {
    expect(isCacheableImage(new URL('https://minio.example/palimpsest/covers/a.webp'), 'image', origin)).toBe(true)
    expect(isCacheableImage(new URL(`${origin}/placeholder-cover.svg`), 'image', origin)).toBe(true)
    expect(isCacheableImage(new URL(`${origin}/api/v1/users/me/avatar`), 'image', origin)).toBe(false)
    expect(isCacheableImage(new URL(`${origin}/novel/1`), 'document', origin)).toBe(false)
    expect(isCacheableImage(new URL('data:image/png;base64,AAAA'), 'image', origin)).toBe(false)
  })

  it('stores only anonymous, successful HTML pages', () => {
    expect(isCacheablePage(200, headers({ 'content-type': 'text/html;charset=utf-8' }))).toBe(true)
    expect(isCacheablePage(200, headers({ 'content-type': 'text/html', [PERSONALIZED_HEADER]: '1' }))).toBe(false)
    expect(isCacheablePage(200, headers({ 'content-type': 'text/html', 'cache-control': 'private, no-store' }))).toBe(false)
    expect(isCacheablePage(404, headers({ 'content-type': 'text/html' }))).toBe(false)
    expect(isCacheablePage(200, headers({ 'content-type': 'application/json' }))).toBe(false)
  })

  it('recognizes a signed-in visitor from the persisted auth cookie', () => {
    expect(hasSession(JSON.stringify({ accessToken: 'tok', refreshToken: 'r', user: null }))).toBe(true)
    expect(hasSession(JSON.stringify({ accessToken: null, refreshToken: null, user: null }))).toBe(false)
    expect(hasSession('not json')).toBe(false)
    expect(hasSession(undefined)).toBe(false)
  })
})
