export default defineNuxtConfig({
  devtools: { enabled: true },

  modules: [
    '@pinia/nuxt',
    '@unocss/nuxt',
    '@vueuse/nuxt',
  ],

  css: ['~/assets/css/main.css'],

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
    '/profile/**': { ssr: false },
    '/admin/**': { ssr: false },
  },

  compatibilityDate: '2024-04-03',
})
