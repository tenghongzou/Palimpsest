// Marks <html data-hydrated> once the app has hydrated (or mounted, for
// client-rendered routes). The UI locale's messages load before hydration, so
// there is a short window after `load` where inputs are not yet reactive; E2E
// tests wait for this marker before interacting.
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.hook('app:suspense:resolve', () => {
    document.documentElement.dataset.hydrated = 'true'
  })
})
