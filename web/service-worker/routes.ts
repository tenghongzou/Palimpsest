// Request classification for the service worker. Pure functions without
// imports so they can be unit tested and bundled into sw.ts as-is.

/** A client-rendered (ssr: false) page the worker precaches and serves offline for CSR routes. */
export const APP_SHELL_URL = '/app-shell'
/** Static page (public/offline/index.html) shown for navigations that fail offline and have no usable cache. */
export const OFFLINE_PAGE_URL = '/offline'
/**
 * The locale messages endpoint (`/_i18n/<deployment hash>/<locale>/messages.json`)
 * ignores the hash segment; the worker precaches it under this fixed one.
 */
export const I18N_PRECACHE_HASH = 'sw'

export const PAGES_CACHE = 'palimpsest-pages'
export const IMAGES_CACHE = 'palimpsest-images'

/**
 * Header the server sets on HTML rendered for a signed-in visitor (the auth
 * cookie is hydrated into the page). Such responses are never cached.
 */
export const PERSONALIZED_HEADER = 'x-palimpsest-personalized'

/**
 * Paths the worker leaves to the network untouched: the API (user data lives
 * in the sql.js store, never in the SW cache), the admin console, build
 * assets (precached), Nuxt internals and the worker itself.
 */
const BYPASS_PREFIXES = ['/api/', '/admin', '/_nuxt/', '/__nuxt_', '/_i18n/', '/sw.js', '/workbox-']

/** Client-rendered routes (routeRules `ssr: false`) whose HTML is the generic app shell. */
const SHELL_PREFIXES = ['/read/', '/bookshelf', '/notifications', '/profile']

function hasPrefix(pathname: string, prefix: string): boolean {
  // "/x/", "/x-", "/x_" and file names match as raw prefixes; "/x" matches the segment.
  if (/[/_-]$/.test(prefix) || prefix.includes('.')) return pathname.startsWith(prefix)
  return pathname === prefix || pathname.startsWith(`${prefix}/`)
}

/** Whether a navigation to `pathname` is handled by the worker (network first, offline fallback). */
export function isHandledNavigation(pathname: string): boolean {
  if (pathname === '/api' || pathname === '/admin') return false
  return !BYPASS_PREFIXES.some(p => hasPrefix(pathname, p))
}

/** Whether `pathname` is a client-rendered route that can boot from the app shell offline. */
export function isAppShellRoute(pathname: string): boolean {
  return SHELL_PREFIXES.some(p => hasPrefix(pathname, p))
}

/** The locale of an i18n messages request, or null for other URLs. */
export function i18nMessagesLocale(pathname: string): string | null {
  const m = /^\/_i18n\/[^/]+\/([A-Za-z-]+)\/messages\.json$/.exec(pathname)
  return m ? m[1]! : null
}

/** The precached URL serving the messages of `locale`. */
export function i18nPrecacheUrl(locale: string): string {
  return `/_i18n/${I18N_PRECACHE_HASH}/${locale}/messages.json`
}

/** Images (covers, banners, avatars) cached at runtime; never API responses. */
export function isCacheableImage(url: URL, destination: string, origin: string): boolean {
  if (destination !== 'image') return false
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return false
  if (url.origin === origin && !isHandledNavigation(url.pathname) && !url.pathname.startsWith('/_nuxt/')) return false
  return true
}

/** HTML responses that may be stored for offline use. */
export function isCacheablePage(status: number, headers: { get: (name: string) => string | null }): boolean {
  if (status !== 200) return false
  if (headers.get(PERSONALIZED_HEADER)) return false
  if (/no-store|private/i.test(headers.get('cache-control') ?? '')) return false
  return (headers.get('content-type') ?? '').includes('text/html')
}
