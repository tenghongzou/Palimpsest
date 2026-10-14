import { describe, expect, it } from 'vitest'
import { makeT } from '../i18n'
import {
  DEVICE_ID_KEY,
  deviceNameFromUserAgent,
  getDeviceId,
  markRegisteredThisSession,
  readDeviceRecord,
  registeredThisSession,
  writeDeviceRecord,
} from '~/utils/device'

function memoryStorage() {
  const data = new Map<string, string>()
  return {
    getItem: (k: string) => data.get(k) ?? null,
    setItem: (k: string, v: string) => void data.set(k, v),
    removeItem: (k: string) => void data.delete(k),
    data,
  }
}

const UA = {
  chromeWindows: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
  edgeWindows: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0',
  firefoxLinux: 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0',
  safariMac: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
  safariIphone: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
  chromeIos: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/129.0.6668.69 Mobile/15E148 Safari/604.1',
  chromeAndroid: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36',
  samsung: 'Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/26.0 Chrome/122.0.0.0 Mobile Safari/537.36',
  operaWindows: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 OPR/114.0.0.0',
  ipad: 'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
  chromeOs: 'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
}

describe('deviceNameFromUserAgent', () => {
  const t = makeT('zh-TW')
  const zh = { browserOn: (os: string) => t('devices.browserOn', { os }), generic: t('devices.webBrowser') }

  it.each([
    [UA.chromeWindows, 'Chrome on Windows'],
    [UA.edgeWindows, 'Edge on Windows'],
    [UA.firefoxLinux, 'Firefox on Linux'],
    [UA.safariMac, 'Safari on macOS'],
    [UA.safariIphone, 'Safari on iOS'],
    [UA.chromeIos, 'Chrome on iOS'],
    [UA.chromeAndroid, 'Chrome on Android'],
    [UA.samsung, 'Samsung Internet on Android'],
    [UA.operaWindows, 'Opera on Windows'],
    [UA.ipad, 'Safari on iPadOS'],
    [UA.chromeOs, 'Chrome on ChromeOS'],
  ])('%s', (ua, name) => {
    expect(deviceNameFromUserAgent(ua)).toBe(name)
  })

  it('falls back for unknown agents', () => {
    expect(deviceNameFromUserAgent('', zh)).toBe('網頁瀏覽器')
    expect(deviceNameFromUserAgent(undefined, zh)).toBe('網頁瀏覽器')
    expect(deviceNameFromUserAgent('curl/8.0', zh)).toBe('網頁瀏覽器')
    expect(deviceNameFromUserAgent('SomeBot (Windows NT 10.0)', zh)).toBe('瀏覽器 on Windows')
    expect(deviceNameFromUserAgent('SomeBot (Windows NT 10.0)')).toBe('Browser on Windows')
    expect(deviceNameFromUserAgent('')).toBe('Web browser')
  })

  it('stays within the 100 character limit', () => {
    expect(deviceNameFromUserAgent(UA.chromeWindows).length).toBeLessThanOrEqual(100)
  })
})

describe('device id and records', () => {
  it('creates a uuid once and reuses it', () => {
    const storage = memoryStorage()
    const id = getDeviceId(storage)
    expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
    expect(storage.data.get(DEVICE_ID_KEY)).toBe(id)
    expect(getDeviceId(storage)).toBe(id)
  })

  it('keeps a stable id when storage is unavailable', () => {
    const broken = {
      getItem: () => { throw new Error('blocked') },
      setItem: () => { throw new Error('blocked') },
      removeItem: () => {},
    }
    const first = getDeviceId(broken)
    expect(getDeviceId(broken)).toBe(first)
    expect(getDeviceId(null)).toBe(first)
  })

  it('stores the server record per user', () => {
    const storage = memoryStorage()
    expect(readDeviceRecord(storage)).toBeNull()
    writeDeviceRecord({ userId: 'u1', id: 'd1' }, storage)
    expect(readDeviceRecord(storage)).toEqual({ userId: 'u1', id: 'd1' })
    writeDeviceRecord(null, storage)
    expect(readDeviceRecord(storage)).toBeNull()
    storage.setItem('palimpsest.device_record', '{oops')
    expect(readDeviceRecord(storage)).toBeNull()
  })

  it('remembers registration for the session and user', () => {
    const session = memoryStorage()
    expect(registeredThisSession('u1', session)).toBe(false)
    markRegisteredThisSession('u1', session)
    expect(registeredThisSession('u1', session)).toBe(true)
    expect(registeredThisSession('u2', session)).toBe(false)
    markRegisteredThisSession(null, session)
    expect(registeredThisSession('u1', session)).toBe(false)
  })
})
