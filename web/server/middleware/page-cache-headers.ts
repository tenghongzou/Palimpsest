// Cache headers for server-rendered pages.
// - Pages render in the visitor's UI language (cookie, then Accept-Language).
// - The auth store is persisted in the `auth` cookie and hydrated into the
//   page payload, so HTML rendered for a signed-in visitor is private: it is
//   marked so neither shared caches nor the service worker store it.
import { PERSONALIZED_HEADER } from '~/service-worker/routes'
import { hasSession } from '../utils/session'

const SKIP = /^\/(?:api|_nuxt|__nuxt|_i18n)(?:\/|$)|\.[a-z0-9]+$/i

export default defineEventHandler((event) => {
  if (event.method !== 'GET' || SKIP.test(event.path.split('?')[0] ?? '')) return
  appendResponseHeader(event, 'vary', 'Cookie, Accept-Language')
  if (hasSession(getCookie(event, 'auth'))) {
    setResponseHeader(event, PERSONALIZED_HEADER, '1')
    setResponseHeader(event, 'cache-control', 'private, no-store')
  }
})
