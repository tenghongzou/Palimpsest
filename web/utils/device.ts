// Identifies this browser for the signed-in device list (POST /users/me/devices).
import { newUuid } from '~/utils/uuid'

export const DEVICE_ID_KEY = 'palimpsest.device_id'
/** The server record (`Device.id`) registered for this browser, per user. */
export const DEVICE_RECORD_KEY = 'palimpsest.device_record'
/** Set in sessionStorage once this tab session has registered the device. */
export const DEVICE_SESSION_KEY = 'palimpsest.device_registered'

const MAX_NAME_LENGTH = 100

interface StorageLike {
  getItem: (key: string) => string | null
  setItem: (key: string, value: string) => void
  removeItem: (key: string) => void
}

let memoryId: string | null = null

function safeStorage(kind: 'localStorage' | 'sessionStorage'): StorageLike | null {
  try {
    const s = (globalThis as unknown as Record<string, StorageLike | undefined>)[kind]
    return s ?? null
  }
  catch {
    return null
  }
}

/** A stable per-browser id, created once and kept in localStorage. */
export function getDeviceId(storage: StorageLike | null = safeStorage('localStorage')): string {
  try {
    const existing = storage?.getItem(DEVICE_ID_KEY)
    if (existing) return existing
    const id = newUuid()
    storage?.setItem(DEVICE_ID_KEY, id)
    if (storage) return id
  }
  catch {}
  // Storage blocked (e.g. privacy mode): stable for this page load at least.
  memoryId ??= newUuid()
  return memoryId
}

function detectBrowser(ua: string): string | null {
  if (/Edg(e|A|iOS)?\//.test(ua)) return 'Edge'
  if (/OPR\/|Opera/.test(ua)) return 'Opera'
  if (/SamsungBrowser\//.test(ua)) return 'Samsung Internet'
  if (/Firefox\/|FxiOS\//.test(ua)) return 'Firefox'
  if (/Chrome\/|CriOS\/|Chromium\//.test(ua)) return 'Chrome'
  if (/Safari\//.test(ua) && /Version\//.test(ua)) return 'Safari'
  return null
}

function detectOs(ua: string): string | null {
  if (/Windows/.test(ua)) return 'Windows'
  if (/Android/.test(ua)) return 'Android'
  if (/iPad/.test(ua)) return 'iPadOS'
  if (/iPhone|iPod/.test(ua)) return 'iOS'
  if (/CrOS/.test(ua)) return 'ChromeOS'
  if (/Mac OS X|Macintosh/.test(ua)) return 'macOS'
  if (/Linux/.test(ua)) return 'Linux'
  return null
}

/** A friendly name such as "Chrome on Windows" from a user agent string. */
export function deviceNameFromUserAgent(ua: string | null | undefined): string {
  const s = ua || ''
  const browser = detectBrowser(s)
  const os = detectOs(s)
  let name: string
  if (browser && os) name = `${browser} on ${os}`
  else if (browser) name = browser
  else if (os) name = `瀏覽器 on ${os}`
  else name = '網頁瀏覽器'
  return name.slice(0, MAX_NAME_LENGTH)
}

export interface StoredDeviceRecord {
  userId: string
  id: string
}

export function readDeviceRecord(storage: StorageLike | null = safeStorage('localStorage')): StoredDeviceRecord | null {
  try {
    const raw = storage?.getItem(DEVICE_RECORD_KEY)
    if (!raw) return null
    const v = JSON.parse(raw) as Partial<StoredDeviceRecord>
    return typeof v.userId === 'string' && typeof v.id === 'string' ? { userId: v.userId, id: v.id } : null
  }
  catch {
    return null
  }
}

export function writeDeviceRecord(record: StoredDeviceRecord | null, storage: StorageLike | null = safeStorage('localStorage')) {
  try {
    if (record) storage?.setItem(DEVICE_RECORD_KEY, JSON.stringify(record))
    else storage?.removeItem(DEVICE_RECORD_KEY)
  }
  catch {}
}

/** Whether this tab session already registered the device for `userId`. */
export function registeredThisSession(userId: string, storage: StorageLike | null = safeStorage('sessionStorage')): boolean {
  try {
    return storage?.getItem(DEVICE_SESSION_KEY) === userId
  }
  catch {
    return false
  }
}

export function markRegisteredThisSession(userId: string | null, storage: StorageLike | null = safeStorage('sessionStorage')) {
  try {
    if (userId) storage?.setItem(DEVICE_SESSION_KEY, userId)
    else storage?.removeItem(DEVICE_SESSION_KEY)
  }
  catch {}
}
