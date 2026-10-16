import { APP_SHELL_URL, I18N_PRECACHE_HASH, OFFLINE_PAGE_URL } from './service-worker/routes'
import { LOCALE_COOKIE } from './i18n/constants'

// Changes with every build so the service worker re-fetches the app shell and
// the locale messages it precaches (their URLs do not carry a content hash).
const BUILD_REVISION = Date.now().toString(36)

/** Set NUXT_PWA_DEV=1 to register the service worker in `nuxt dev`. */
const pwaInDev = process.env.NUXT_PWA_DEV === '1'

export default defineNuxtConfig({
  devtools: { enabled: true },

  modules: [
    '@pinia/nuxt',
    'pinia-plugin-persistedstate/nuxt',
    '@unocss/nuxt',
    '@vueuse/nuxt',
    '@nuxtjs/i18n',
    '@vite-pwa/nuxt',
  ],

  app: {
    head: {
      link: [
        { rel: 'icon', href: '/favicon.ico', sizes: '48x48' },
        { rel: 'icon', href: '/favicon.svg', type: 'image/svg+xml' },
        { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
      ],
      meta: [
        { name: 'theme-color', content: '#1890FF' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-title', content: 'Palimpsest' },
      ],
    },
  },

  // Persisted stores (auth, reader settings) live in cookies. Without maxAge
  // they would be session cookies and closing the browser would sign the
  // user out; 30 days matches the refresh token's lifetime.
  piniaPluginPersistedstate: {
    cookieOptions: { maxAge: 60 * 60 * 24 * 30, sameSite: 'lax' },
  },

  css: ['~/assets/css/main.css'],

  // `text-primary` etc. follow the brand color from main.css.
  unocss: {
    theme: { colors: { primary: 'var(--color-primary)' } },
  },

  components: {
    dirs: [
      { path: '~/components', pathPrefix: false },
    ],
  },

  build: {
    transpile: [
      'naive-ui',
      'vueuc',
      '@css-render/vue3-ssr',
      '@juggle/resize-observer',
    ],
  },

  vite: {
    optimizeDeps: {
      include: [
        'naive-ui',
        'vueuc',
        'date-fns-tz/formatInTimeZone',
      ],
    },
  },

  // UI language (not the reader's content translation). URLs stay unprefixed;
  // the locale comes from the cookie, then the browser, then zh-TW. Signed-in
  // users' `language_pref` is applied by plugins/locale.client.ts.
  i18n: {
    strategy: 'no_prefix',
    defaultLocale: 'zh-TW',
    langDir: 'locales',
    locales: [
      { code: 'zh-TW', language: 'zh-TW', name: '繁體中文', file: 'zh-TW.json' },
      { code: 'zh-CN', language: 'zh-CN', name: '简体中文', file: 'zh-CN.json' },
      { code: 'en', language: 'en-US', name: 'English', file: 'en.json' },
    ],
    detectBrowserLanguage: {
      useCookie: true,
      cookieKey: LOCALE_COOKIE,
      redirectOn: 'root',
      fallbackLocale: 'zh-TW',
    },
    vueI18n: './i18n.config.ts',
  },

  pwa: {
    // A custom worker (service-worker/sw.ts): navigations need SSR-aware
    // fallbacks and /api must never be cached, which generateSW cannot express.
    strategies: 'injectManifest',
    srcDir: 'service-worker',
    filename: 'sw.ts',
    registerType: 'prompt',
    injectRegister: false,
    client: { installPrompt: false, periodicSyncForUpdates: 60 * 60 },
    manifest: {
      name: 'Palimpsest',
      short_name: 'Palimpsest',
      description: 'Chinese novel reading platform',
      lang: 'zh-TW',
      theme_color: '#1890FF',
      background_color: '#FFFFFF',
      display: 'standalone',
      start_url: '/',
      scope: '/',
      icons: [
        { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        { src: '/apple-touch-icon.png', sizes: '180x180', type: 'image/png' },
      ],
    },
    injectManifest: {
      // Hashed build output (incl. the sql.js wasm), public icons and the offline page.
      globPatterns: ['_nuxt/**/*.{js,css,wasm,woff2}', '*.{png,svg,ico}', 'offline/index.html'],
      // og-image.png is only fetched by link-preview crawlers.
      globIgnores: ['_nuxt/builds/latest.json', 'og-image.png'],
      maximumFileSizeToCacheInBytes: 5 * 1024 * 1024,
      additionalManifestEntries: [
        // Rendered by the server (ssr: false, so it carries no user data); served
        // for client-rendered routes such as the reader when offline.
        { url: APP_SHELL_URL, revision: BUILD_REVISION },
        ...['zh-TW', 'zh-CN', 'en'].map(locale => ({
          url: `/_i18n/${I18N_PRECACHE_HASH}/${locale}/messages.json`,
          revision: BUILD_REVISION,
        })),
      ],
    },
    devOptions: {
      enabled: pwaInDev,
      type: 'module',
    },
  },

  runtimeConfig: {
    apiBaseUrl: process.env.API_BASE_URL || 'http://localhost:8080',
    public: {
      apiBaseUrl: process.env.NUXT_PUBLIC_API_BASE_URL || '/api',
    },
  },

  routeRules: {
    // SSR + ISR for public SEO pages
    '/': { isr: 600 },
    '/novel/**': { isr: 300 },
    '/category/**': { isr: 600 },
    '/ranking/**': { isr: 600 },
    // CSR for private/interactive pages
    '/read/**': { ssr: false },
    '/bookshelf': { ssr: false },
    '/notifications': { ssr: false },
    '/profile/**': { ssr: false },
    '/admin/**': { ssr: false },
    // The client-rendered app shell the service worker precaches.
    [APP_SHELL_URL]: { ssr: false, headers: { 'cache-control': 'no-store' } },
    [OFFLINE_PAGE_URL]: { headers: { 'cache-control': 'no-cache' } },
    '/sw.js': { headers: { 'cache-control': 'no-cache' } },
  },

  compatibilityDate: '2024-04-03',
})
