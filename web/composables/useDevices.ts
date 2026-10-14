// Signed-in devices (GET/POST /users/me/devices, DELETE /users/me/devices/{id}).
import type { ApiResponse } from '~/utils/api'
import type { ApiDevice, ApiDeviceInput } from '~/types/models'
import {
  deviceNameFromUserAgent,
  getDeviceId,
  markRegisteredThisSession,
  readDeviceRecord,
  registeredThisSession,
  writeDeviceRecord,
} from '~/utils/device'

/** How long logout waits for the device to be removed before going on. */
const UNREGISTER_TIMEOUT_MS = 3000

export function thisDeviceInput(): ApiDeviceInput {
  return {
    device_id: getDeviceId(),
    device_type: 'web',
    device_name: deviceNameFromUserAgent(typeof navigator === 'undefined' ? '' : navigator.userAgent),
  }
}

/** Registers (or refreshes) this browser for the signed-in user. */
export async function registerThisDevice(): Promise<ApiDevice | null> {
  const authStore = useAuthStore()
  const userId = authStore.user?.id
  if (!authStore.isLoggedIn) return null
  const res = await apiFetch<ApiResponse<ApiDevice>>('/users/me/devices', { method: 'POST', body: thisDeviceInput() })
  if (userId && res.data?.id) {
    writeDeviceRecord({ userId, id: res.data.id })
    markRegisteredThisSession(userId)
  }
  return res.data ?? null
}

/**
 * Registers this browser unless this tab session already did for the user.
 * `force` registers anyway (right after signing in). Errors are swallowed.
 */
export async function ensureDeviceRegistered(force = false): Promise<void> {
  const authStore = useAuthStore()
  const userId = authStore.user?.id
  if (!authStore.isLoggedIn) return
  if (!force && userId && registeredThisSession(userId)) return
  try {
    await registerThisDevice()
  }
  catch {}
}

/**
 * Best effort: removes this browser's device record before signing out. Never
 * throws and gives up after a few seconds so logout is not held up.
 */
export async function unregisterThisDevice(): Promise<void> {
  const authStore = useAuthStore()
  const userId = authStore.user?.id
  if (!authStore.isLoggedIn) return
  const work = (async () => {
    const stored = readDeviceRecord()
    let recordId = stored && stored.userId === userId ? stored.id : null
    if (!recordId) {
      const res = await apiFetch<ApiResponse<ApiDevice[]>>('/users/me/devices')
      recordId = res.data?.find(d => d.device_id === getDeviceId())?.id ?? null
    }
    if (recordId) await apiFetch(`/users/me/devices/${recordId}`, { method: 'DELETE' })
  })().catch(() => {})
  await Promise.race([work, new Promise(resolve => setTimeout(resolve, UNREGISTER_TIMEOUT_MS))])
  writeDeviceRecord(null)
  markRegisteredThisSession(null)
}

export function useDevices() {
  const devices = ref<ApiDevice[]>([])
  const loading = ref(false)
  const error = ref<unknown>(null)
  const currentDeviceId = import.meta.client ? getDeviceId() : ''

  async function load() {
    loading.value = true
    error.value = null
    try {
      const res = await apiFetch<ApiResponse<ApiDevice[]>>('/users/me/devices')
      devices.value = res.data ?? []
    }
    catch (e) {
      error.value = e
      throw e
    }
    finally {
      loading.value = false
    }
  }

  async function remove(device: ApiDevice) {
    await apiFetch(`/users/me/devices/${device.id}`, { method: 'DELETE' })
    devices.value = devices.value.filter(d => d.id !== device.id)
    if (device.device_id === currentDeviceId) {
      // Registers again on the next visit.
      writeDeviceRecord(null)
      markRegisteredThisSession(null)
    }
  }

  function isCurrent(device: ApiDevice) {
    return device.device_id === currentDeviceId
  }

  return { devices, loading, error, load, remove, isCurrent }
}
