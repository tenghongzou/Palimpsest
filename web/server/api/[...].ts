// BFF proxy: forwards requests from Nuxt server to Go backend
export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig()
  const path = event.path?.replace(/^\/api/, '') || ''
  const targetUrl = `${config.apiBaseUrl}/api${path}`

  // Append the caller's address so the backend rate limits per browser rather
  // than per Nuxt server. The backend only trusts this header from private networks.
  const forwardedFor = [getRequestHeader(event, 'x-forwarded-for'), getRequestIP(event)]
    .filter(Boolean)
    .join(', ')

  return proxyRequest(event, targetUrl, {
    headers: forwardedFor ? { 'x-forwarded-for': forwardedFor } : {},
  })
})
