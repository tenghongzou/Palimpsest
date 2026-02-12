// BFF proxy: forwards requests from Nuxt server to Go backend
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const path = event.path?.replace(/^\/api/, '') || ''
  const targetUrl = `${config.apiBaseUrl}/api${path}`

  return proxyRequest(event, targetUrl)
})
