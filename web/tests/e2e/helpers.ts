import { expect, type Page } from '@playwright/test'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

export const AUTH_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '.auth')
export const ADMIN_STATE = path.join(AUTH_DIR, 'admin.json')
export const USER_STATE = path.join(AUTH_DIR, 'user.json')
export const USER_INFO = path.join(AUTH_DIR, 'user-info.json')

export const ADMIN = {
  login: process.env.E2E_ADMIN_LOGIN || 'admin',
  password: process.env.E2E_ADMIN_PASSWORD || 'adminpass123',
}

export interface UserInfo {
  username: string
  email: string
  password: string
}

export function readUserInfo(): UserInfo {
  return JSON.parse(fs.readFileSync(USER_INFO, 'utf8')) as UserInfo
}

export function uniqueSuffix(): string {
  return `${Date.now().toString(36)}${Math.floor(Math.random() * 1e4).toString(36)}`
}

/** Fills the login form and waits until the app has left /login. */
export async function loginViaUi(page: Page, login: string, password: string) {
  await page.goto('/login')
  await page.getByPlaceholder('輸入帳號或電子郵件').fill(login)
  await page.getByPlaceholder('輸入密碼').fill(password)
  await page.getByRole('button', { name: '登入' }).click()
  await expect(page).not.toHaveURL(/\/login/)
}

/** Reads the access token persisted by the auth store. */
export async function accessToken(page: Page): Promise<string> {
  const cookies = await page.context().cookies()
  const raw = cookies.find(c => c.name === 'auth')?.value
  if (!raw) throw new Error('no auth cookie')
  return (JSON.parse(decodeURIComponent(raw)) as { accessToken: string }).accessToken
}

/** Calls the API through the BFF with the page's session. */
export async function api<T = unknown>(page: Page, method: string, url: string, data?: unknown): Promise<T> {
  const token = await accessToken(page)
  const res = await page.request.fetch(`/api/v1${url}`, {
    method,
    data,
    headers: { Authorization: `Bearer ${token}` },
  })
  const body = await res.json() as { data: T }
  if (!res.ok()) throw new Error(`${method} ${url} -> ${res.status()} ${JSON.stringify(body)}`)
  return body.data
}

export interface NovelSummary {
  id: string
  title: string
  total_chapters?: number
}

/** A published novel with at least `minChapters` chapters from the home page. */
export async function pickNovel(page: Page, minChapters = 2): Promise<NovelSummary> {
  const res = await page.request.get('/api/v1/novels', { params: { sort_by: 'popular', page_size: 50 } })
  const body = await res.json() as { data: { items: NovelSummary[] } }
  const novel = body.data.items.find(n => (n.total_chapters ?? 0) >= minChapters)
  if (!novel) throw new Error(`no published novel with ${minChapters}+ chapters`)
  return novel
}

/** The published chapters of a novel in reading order. */
export async function chaptersOf(page: Page, novelId: string): Promise<{ id: string, title: string, chapter_number: number }[]> {
  const res = await page.request.get(`/api/v1/novels/${novelId}/chapters`)
  return (await res.json() as { data: { id: string, title: string, chapter_number: number }[] }).data
}

/**
 * expect.poll options. The API rate limits clients (60-120 requests/minute),
 * so polls back off instead of using Playwright's fast default intervals.
 */
export const POLL = { intervals: [500, 1000, 2000, 3000], timeout: 20_000 }

async function remaining(page: Page, authenticated: boolean): Promise<number> {
  const headers: Record<string, string> = {}
  if (authenticated) headers.Authorization = `Bearer ${await accessToken(page)}`
  const res = await page.request.get(authenticated ? '/api/v1/users/me' : '/api/v1/categories', { headers })
  return Number(res.headers()['x-ratelimit-remaining'] ?? 999)
}

/**
 * Waits until the API has quota left for a test (120 requests/minute per
 * user, 60 per IP). Specs call it in beforeEach so a fast run does not trip
 * the limiter.
 */
export async function ensureQuota(page: Page, min = 50) {
  const authenticated = (await page.context().cookies()).some(c => c.name === 'auth')
  for (let i = 0; i < 9; i++) {
    const [user, ip] = await Promise.all([
      authenticated ? remaining(page, true).catch(() => 999) : Promise.resolve(999),
      remaining(page, false).catch(() => 999),
    ])
    if (user >= min && ip >= Math.min(min, 30)) return
    await page.waitForTimeout(10_000)
  }
}
