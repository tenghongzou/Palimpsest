import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { apiFetch, describeError, errorMessage } from '~/utils/api'

interface FakeAuthStore {
  accessToken: string | null
  refreshToken: string | null
  refresh: ReturnType<typeof vi.fn>
}

function httpError(status: number) {
  return Object.assign(new Error(`HTTP ${status}`), { response: { status } })
}

function authHeader(call: unknown[]): string | null {
  const opts = call[1] as { headers: Headers }
  return opts.headers.get('Authorization')
}

describe('apiFetch', () => {
  let store: FakeAuthStore
  let fetchMock: ReturnType<typeof vi.fn>

  beforeEach(() => {
    store = {
      accessToken: 'old-access',
      refreshToken: 'refresh',
      refresh: vi.fn(async () => {
        store.accessToken = 'new-access'
        return true
      }),
    }
    fetchMock = vi.fn()
    vi.stubGlobal('useAuthStore', () => store)
    vi.stubGlobal('$fetch', fetchMock)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('prefixes the path and sends the access token', async () => {
    fetchMock.mockResolvedValueOnce({ code: 0, data: 'ok' })

    const res = await apiFetch<{ data: string }>('/bookshelf', { params: { sort_by: 'recent' } })

    expect(res.data).toBe('ok')
    expect(fetchMock.mock.calls[0][0]).toBe('/api/v1/bookshelf')
    expect(authHeader(fetchMock.mock.calls[0])).toBe('Bearer old-access')
    expect(fetchMock.mock.calls[0][1].params).toEqual({ sort_by: 'recent' })
  })

  it('omits the Authorization header when logged out', async () => {
    store.accessToken = null
    fetchMock.mockResolvedValueOnce({})

    await apiFetch('/novels')

    expect(authHeader(fetchMock.mock.calls[0])).toBeNull()
  })

  it('refreshes once on 401 and retries with the new token', async () => {
    fetchMock.mockRejectedValueOnce(httpError(401)).mockResolvedValueOnce({ code: 0 })

    await apiFetch('/bookshelf')

    expect(store.refresh).toHaveBeenCalledTimes(1)
    expect(fetchMock).toHaveBeenCalledTimes(2)
    expect(authHeader(fetchMock.mock.calls[1])).toBe('Bearer new-access')
  })

  it('shares a single refresh between concurrent 401s', async () => {
    fetchMock
      .mockRejectedValueOnce(httpError(401))
      .mockRejectedValueOnce(httpError(401))
      .mockResolvedValue({ code: 0 })

    await Promise.all([apiFetch('/a'), apiFetch('/b')])

    expect(store.refresh).toHaveBeenCalledTimes(1)
  })

  it('rethrows when the refresh fails', async () => {
    store.refresh.mockResolvedValueOnce(false)
    fetchMock.mockRejectedValueOnce(httpError(401))

    await expect(apiFetch('/bookshelf')).rejects.toThrow('HTTP 401')
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it('does not refresh for other errors or without a refresh token', async () => {
    fetchMock.mockRejectedValueOnce(httpError(500))
    await expect(apiFetch('/x')).rejects.toThrow('HTTP 500')

    store.refreshToken = null
    fetchMock.mockRejectedValueOnce(httpError(401))
    await expect(apiFetch('/x')).rejects.toThrow('HTTP 401')

    expect(store.refresh).not.toHaveBeenCalled()
  })
})

describe('error helpers', () => {
  const httpError = (status: number, message?: string) =>
    Object.assign(new Error(`HTTP ${status}`), { response: { status }, data: message ? { code: 1, message } : undefined })

  it('prefers the per-status message', () => {
    expect(describeError(httpError(409), { 409: '已存在' }, '失敗')).toBe('已存在')
  })

  it('falls back to common messages and then the fallback', () => {
    expect(describeError(httpError(429), {}, '失敗')).toBe('操作太頻繁，請稍後再試')
    expect(describeError(new Error('network'), {}, '失敗')).toBe('無法連線到伺服器，請檢查網路')
    expect(describeError(httpError(500), {}, '失敗')).toBe('失敗')
  })

  it('reads the envelope message', () => {
    expect(errorMessage(httpError(400, 'bad'), 'x')).toBe('bad')
    expect(errorMessage(new Error('y'), 'x')).toBe('x')
  })
})
