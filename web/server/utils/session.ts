/** Whether the persisted auth store (the `auth` cookie) holds an access token. */
export function hasSession(cookie: string | undefined): boolean {
  if (!cookie) return false
  try {
    const state = JSON.parse(cookie) as { accessToken?: unknown }
    return typeof state?.accessToken === 'string' && state.accessToken.length > 0
  }
  catch {
    return false
  }
}
