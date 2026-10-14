import { type BrowserContext, type Page } from '@playwright/test'
import { test, expect, USER_STATE, chaptersOf, ensureQuota, pickNovel } from './helpers'

// The other specs block service workers; these need the real one (production build only).
test.use({ storageState: USER_STATE, serviceWorkers: 'allow' })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

/** Waits until a service worker is active for the page (precaching finished). */
async function swActive(page: Page): Promise<string> {
  return page.evaluate(async () => {
    const reg = await navigator.serviceWorker.ready
    return reg.active?.state ?? 'none'
  })
}

async function waitForWorker(context: BrowserContext, page: Page) {
  await expect.poll(() => swActive(page), { timeout: 60_000 }).toBe('activated')
  expect(context.serviceWorkers().some(w => w.url().endsWith('/sw.js'))).toBe(true)
}

test('serves and links the web app manifest', async ({ page }) => {
  await page.goto('/')
  const href = await page.locator('link[rel="manifest"]').getAttribute('href')
  expect(href).toBeTruthy()
  const res = await page.request.get(href!)
  expect(res.ok()).toBe(true)
  const manifest = await res.json() as { name: string, short_name: string, theme_color: string, display: string, start_url: string, icons: { src: string, purpose?: string }[] }
  expect(manifest).toMatchObject({ name: 'Palimpsest', theme_color: '#1890FF', display: 'standalone', start_url: '/' })
  expect(manifest.icons.map(i => i.src)).toEqual(expect.arrayContaining(['/icon-192.png', '/icon-512.png', '/icon-512-maskable.png']))
  expect(manifest.icons.find(i => i.src === '/icon-512-maskable.png')?.purpose).toBe('maskable')
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', '#1890FF')
})

test('registers the service worker in the production build', async ({ page, context }) => {
  await page.goto('/')
  await waitForWorker(context, page)
  // It precached the app shell, the offline page and the locale messages.
  const cached = await page.evaluate(async () => {
    const urls: string[] = []
    for (const name of await caches.keys()) {
      for (const req of await (await caches.open(name)).keys()) urls.push(new URL(req.url).pathname)
    }
    return urls
  })
  expect(cached).toEqual(expect.arrayContaining(['/app-shell', '/offline', '/_i18n/sw/zh-TW/messages.json']))
  // User data from the API is never put in the worker's caches.
  expect(cached.filter(u => u.startsWith('/api/'))).toEqual([])
})

test('offline: a cached chapter opens from the app shell, other pages show the offline page', async ({ page, context }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)

  // Read the chapter online so it lands in the sql.js store, with the worker active.
  await page.goto(`/read/${first.id}`)
  await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
  await waitForWorker(context, page)
  // The local database is persisted to IndexedDB about a second after a change.
  await page.waitForTimeout(2500)

  await context.setOffline(true)
  try {
    // A full reload of a client-rendered route boots from the precached shell.
    await page.goto(`/read/${first.id}`)
    await expect(page.getByTestId('offline-notice')).toBeVisible()
    await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
    await expect(page.getByTestId('reader-prev')).toHaveText('上一章')

    // A server-rendered page that was never cached falls back to the offline page.
    await page.goto(`/novel/${novel.id}?offline-check=${Date.now()}`)
    await expect(page.getByTestId('offline-page')).toBeVisible()
    await expect(page.locator('h1')).toHaveText('目前處於離線狀態')
  }
  finally {
    await context.setOffline(false)
  }
})
