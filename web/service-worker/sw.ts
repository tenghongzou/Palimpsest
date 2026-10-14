// Palimpsest service worker (built by @vite-pwa/nuxt, injectManifest).
//
// - Precaches the hashed build output, icons, the offline page, a
//   client-rendered app shell and the locale messages.
// - Navigations: network first. Client-rendered routes (reader, bookshelf …)
//   fall back to the app shell so they boot offline and read chapters from the
//   sql.js store; other pages fall back to anonymous cached HTML or the offline page.
// - Images: stale-while-revalidate with expiration.
// - /api is never handled here: user data (chapters, progress, bookmarks) is
//   cached by the app's own sql.js store, so the worker cannot serve it stale.
// - Updates wait for the user (registerType "prompt"): the new worker only
//   takes over after the page posts SKIP_WAITING.
import { cleanupOutdatedCaches, matchPrecache, precacheAndRoute } from 'workbox-precaching'
import { registerRoute } from 'workbox-routing'
import { NetworkFirst, NetworkOnly, StaleWhileRevalidate } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'
import { CacheableResponsePlugin } from 'workbox-cacheable-response'
import {
  APP_SHELL_URL,
  IMAGES_CACHE,
  OFFLINE_PAGE_URL,
  PAGES_CACHE,
  i18nMessagesLocale,
  i18nPrecacheUrl,
  isAppShellRoute,
  isCacheableImage,
  isCacheablePage,
  isHandledNavigation,
} from './routes'

// Minimal worker-scope typing; the app's tsconfig uses the DOM lib.
interface ExtendableEventLike extends Event {
  waitUntil: (promise: Promise<unknown>) => void
}
interface WorkerScope {
  __WB_MANIFEST: Array<string | { url: string, revision: string | null }>
  location: Location
  skipWaiting: () => Promise<void>
  addEventListener: ((type: 'message', listener: (event: MessageEvent) => void) => void)
    & ((type: 'activate', listener: (event: ExtendableEventLike) => void) => void)
}
declare const self: WorkerScope

const NETWORK_TIMEOUT_SECONDS = 4

precacheAndRoute(self.__WB_MANIFEST)
cleanupOutdatedCaches()

self.addEventListener('message', (event) => {
  if (event.data?.type === 'SKIP_WAITING') void self.skipWaiting()
})

// Cached HTML references the previous build's assets, which the new precache
// no longer holds; start over when a new worker takes control.
self.addEventListener('activate', (event) => {
  event.waitUntil(caches.delete(PAGES_CACHE))
})

async function offlinePage(): Promise<Response> {
  return (await matchPrecache(OFFLINE_PAGE_URL)) ?? Response.error()
}

// ------------------------------------------------------------ navigations

const shellRouteNetwork = new NetworkOnly({ networkTimeoutSeconds: NETWORK_TIMEOUT_SECONDS })

const pagesNetworkFirst = new NetworkFirst({
  cacheName: PAGES_CACHE,
  networkTimeoutSeconds: NETWORK_TIMEOUT_SECONDS,
  plugins: [
    // Only anonymous, public HTML: pages rendered for a signed-in visitor carry
    // their session in the payload.
    { cacheWillUpdate: async ({ response }) => isCacheablePage(response.status, response.headers) ? response : null },
    new ExpirationPlugin({ maxEntries: 50, maxAgeSeconds: 7 * 24 * 60 * 60, purgeOnQuotaError: true }),
  ],
})

registerRoute(
  ({ request, url }) => request.mode === 'navigate'
    && url.origin === self.location.origin
    && isHandledNavigation(url.pathname),
  async (options) => {
    const { pathname } = options.url
    if (isAppShellRoute(pathname)) {
      try {
        return await shellRouteNetwork.handle(options)
      }
      catch {
        return (await matchPrecache(APP_SHELL_URL)) ?? offlinePage()
      }
    }
    try {
      return await pagesNetworkFirst.handle(options)
    }
    catch {
      return offlinePage()
    }
  },
)

// --------------------------------------------------------- locale messages

const messagesNetwork = new NetworkOnly({ networkTimeoutSeconds: NETWORK_TIMEOUT_SECONDS })

registerRoute(
  ({ url }) => url.origin === self.location.origin && i18nMessagesLocale(url.pathname) !== null,
  async (options) => {
    const locale = i18nMessagesLocale(options.url.pathname)!
    try {
      const response = await messagesNetwork.handle(options)
      if (response.ok) return response
    }
    catch {}
    return (await matchPrecache(i18nPrecacheUrl(locale))) ?? Response.error()
  },
)

// ------------------------------------------------------------------ images

registerRoute(
  ({ request, url }) => isCacheableImage(url, request.destination, self.location.origin),
  new StaleWhileRevalidate({
    cacheName: IMAGES_CACHE,
    plugins: [
      // Covers come from object storage on another origin (opaque responses).
      new CacheableResponsePlugin({ statuses: [0, 200] }),
      new ExpirationPlugin({ maxEntries: 200, maxAgeSeconds: 30 * 24 * 60 * 60, purgeOnQuotaError: true }),
    ],
  }),
)
