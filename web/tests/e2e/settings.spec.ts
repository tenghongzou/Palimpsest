import { expect, test } from '@playwright/test'
import fs from 'node:fs'
import { USER_INFO, USER_STATE, api, readUserInfo, uniqueSuffix, POLL, ensureQuota } from './helpers'

test.use({ storageState: USER_STATE })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

// A 1x1 PNG.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=', 'base64')

test('profile shows reading stats', async ({ page }) => {
  await page.goto('/profile')
  await expect(page.getByText('閱讀統計')).toBeVisible()
  await expect(page.getByTestId('reading-chart')).toBeVisible()
  await page.getByText('近 12 個月').click()
  await expect(page.getByTestId('reading-chart')).toContainText('/')
})

test('edit profile, upload an avatar and sync reading settings', async ({ page }) => {
  const nickname = `改名${uniqueSuffix()}`.slice(0, 20)
  await page.goto('/profile/settings')
  await page.getByPlaceholder('顯示名稱').fill(nickname)
  await page.getByPlaceholder('介紹一下自己').fill('喜歡讀科幻與武俠。')
  await page.getByRole('button', { name: '儲存個人資料' }).click()
  await expect(page.getByText('個人資料已儲存')).toBeVisible()
  expect((await api<{ nickname: string, bio: string }>(page, 'GET', '/users/me')).nickname).toBe(nickname)

  await page.goto('/profile')
  await expect(page.getByTestId('profile-nickname')).toHaveText(nickname)

  // Avatar: oversized files are rejected client-side; a small PNG uploads
  // unless object storage is not configured (503).
  await page.goto('/profile/settings')
  await page.getByTestId('avatar-input').setInputFiles({ name: 'big.png', mimeType: 'image/png', buffer: Buffer.alloc(2 * 1024 * 1024 + 1) })
  await expect(page.getByText('圖片超過 2 MB')).toBeVisible()
  const upload = page.waitForResponse(r => r.url().includes('/users/me/avatar'))
  await page.getByTestId('avatar-input').setInputFiles({ name: 'a.png', mimeType: 'image/png', buffer: PNG })
  const response = await upload
  if (response.status() === 503) await expect(page.getByText('圖片儲存服務暫時無法使用')).toBeVisible()
  else await expect(page.getByText('頭像已更新')).toBeVisible()

  // Reading settings are pushed to the account …
  await page.getByTestId('theme-dark').click()
  await expect.poll(async () => (await api<{ theme: string }>(page, 'GET', '/users/me/reading-settings')).theme, POLL).toBe('dark')

  // … and the server copy wins when the app loads.
  await api(page, 'PUT', '/users/me/reading-settings', {
    font_size: 24, line_height: 2, letter_spacing: 0, margin: 16, font_family: 'serif', theme: 'green',
    reading_mode: 'scroll', brightness: 100, keep_screen_on: true, auto_chapter: true,
  })
  await page.reload()
  await expect(page.getByTestId('font-size-value')).toHaveText('24')
  await page.getByRole('button', { name: '重置為預設' }).click()
  await expect.poll(async () => (await api<{ font_size: number, theme: string }>(page, 'GET', '/users/me/reading-settings')), POLL)
    .toMatchObject({ font_size: 18, theme: 'white' })
})

test('change password and log in with the new one', async ({ page }) => {
  // Runs last: it ends the shared reader session.
  const user = readUserInfo()
  const next = `${user.password}-2`
  await page.goto('/profile/settings')
  await page.getByPlaceholder('目前的密碼').fill('wrong-password')
  await page.getByPlaceholder('至少 8 個字元').fill(next)
  await page.getByPlaceholder('再次輸入新密碼').fill(next)
  await page.getByRole('button', { name: '變更密碼' }).click()
  await expect(page.getByText('目前密碼不正確')).toBeVisible()

  await page.getByPlaceholder('目前的密碼').fill(user.password)
  await page.getByRole('button', { name: '變更密碼' }).click()
  await expect(page).toHaveURL(/\/login/)

  await page.getByPlaceholder('輸入帳號或電子郵件').fill(user.username)
  await page.getByPlaceholder('輸入密碼').fill(next)
  await page.getByRole('button', { name: '登入' }).click()
  await expect(page).not.toHaveURL(/\/login/)
  fs.writeFileSync(USER_INFO, JSON.stringify({ ...user, password: next }))
})
