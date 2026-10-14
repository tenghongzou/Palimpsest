export default defineNuxtConfig({
  devtools: { enabled: true },

  modules: [
    '@pinia/nuxt',
    'pinia-plugin-persistedstate/nuxt',
    '@unocss/nuxt',
    '@vueuse/nuxt',
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
      ],
    },
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
  },

  compatibilityDate: '2024-04-03',
})
