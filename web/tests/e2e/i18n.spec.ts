import { type Page } from '@playwright/test'
import { test, expect, USER_STATE, api, ensureQuota, hydrateOnNavigate, loginViaUi, readUserInfo, POLL } from './helpers'

const LOCALE_COOKIE = 'palimpsest_locale'

async function localeCookie(page: Page): Promise<string | undefined> {
  return (await page.context().cookies()).find(c => c.name === LOCALE_COOKIE)?.value
}

async function chooseLanguage(page: Page, code: 'zh-TW' | 'zh-CN' | 'en') {
  await page.getByTestId('language-switcher').first().click()
  await page.getByTestId(`language-option-${code}`).click()
}

test.describe('anonymous visitors', () => {
  test.use({ locale: 'en-US' })

  test('follow the browser language, switch languages and keep the choice in a cookie', async ({ page }) => {
    await ensureQuota(page)
    await page.goto('/')
    // Server-rendered in English for an English browser.
    await expect(page.locator('html')).toHaveAttribute('lang', 'en')
    await expect(page.getByRole('link', { name: 'Rankings' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Log in' })).toBeVisible()

    await chooseLanguage(page, 'zh-CN')
    await expect(page.locator('html')).toHaveAttribute('lang', 'zh-CN')
    await expect(page.getByRole('link', { name: '排行' })).toBeVisible()
    await expect(page.getByRole('button', { name: '登录' })).toBeVisible()
    expect(await localeCookie(page)).toBe('zh-CN')

    // The cookie wins over the browser language on the next (server-rendered) visit.
    await page.goto('/ranking')
    await expect(page.getByRole('heading', { name: '排行榜' })).toBeVisible()
    await expect(page).toHaveTitle(/排行榜 — Palimpsest/)

    // Back to the default language.
    await chooseLanguage(page, 'zh-TW')
    await expect(page.locator('html')).toHaveAttribute('lang', 'zh-TW')
    await expect(page.getByRole('heading', { name: '排行榜' })).toBeVisible()
    await page.goto('/login')
    await expect(page.getByPlaceholder('輸入帳號或電子郵件')).toBeVisible()
  })
})

test.describe('signed-in readers', () => {
  test.use({ storageState: USER_STATE })

  // Other specs share this account and expect zh-TW; reset it even if the test times out.
  test.afterEach(async ({ page }) => {
    await api(page, 'PATCH', '/users/me', { language_pref: 'zh-TW' })
  })

  test('language_pref is saved to the account and applied after logging in again', async ({ page, browser, baseURL }) => {
    await ensureQuota(page)
    await page.goto('/profile/settings')
    await expect(page.getByRole('heading', { name: '帳號設定' })).toBeVisible()

    // Choosing English in settings switches the UI at once and updates the account.
    await page.getByTestId('settings-language').click()
    await page.locator('.n-base-select-option', { hasText: 'English' }).click()
    await expect(page.getByRole('heading', { name: 'Account settings' })).toBeVisible()
    await expect(page.locator('html')).toHaveAttribute('lang', 'en')
    await expect.poll(async () => (await api<{ language_pref: string }>(page, 'GET', '/users/me')).language_pref, POLL).toBe('en')

    // A fresh browser (zh-TW, no locale cookie) logs in and gets the account's language.
    const user = readUserInfo()
    // Explicitly signed out: contexts created in a test inherit the spec's storageState.
    const context = await browser.newContext({ baseURL, locale: 'zh-TW', serviceWorkers: 'block', storageState: { cookies: [], origins: [] } })
    try {
      const fresh = hydrateOnNavigate(await context.newPage())
      await loginViaUi(fresh, user.username, user.password)
      await expect(fresh.locator('html')).toHaveAttribute('lang', 'en')
      await expect(fresh.getByRole('link', { name: 'Bookshelf' })).toBeVisible()
      expect(await localeCookie(fresh)).toBe('en')

      // Switching from the header updates the account as well.
      await chooseLanguage(fresh, 'zh-CN')
      await expect(fresh.getByRole('link', { name: '书架' })).toBeVisible()
      await expect.poll(async () => (await api<{ language_pref: string }>(fresh, 'GET', '/users/me')).language_pref, POLL).toBe('zh-CN')
    }
    finally {
      await context.close()
    }
  })
})
