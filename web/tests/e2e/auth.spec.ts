import { test, expect, uniqueSuffix } from './helpers'

// Auth endpoints allow 5 requests/minute per IP: this file registers once,
// logs in once, and calls forgot/reset password once each.

test('register, log out and log back in', async ({ page }) => {
  const suffix = uniqueSuffix()
  const username = `reg${suffix}`
  const password = 'register-pass-1'

  await page.goto('/register')
  await page.getByPlaceholder('4-20 個字元').fill(username)
  await page.getByPlaceholder('顯示名稱').fill(`新讀者${suffix}`)
  await page.getByPlaceholder('your@email.com').fill(`${username}@example.com`)
  await page.getByPlaceholder('至少 8 個字元').fill(password)
  await page.getByPlaceholder('再次輸入密碼').fill(password)
  await page.getByRole('button', { name: '註冊' }).click()
  await expect(page).toHaveURL(/\/$/)
  await expect(page.getByTestId('user-menu')).toBeVisible()

  // Profile shows the freshly fetched user.
  await page.goto('/profile')
  await expect(page.getByTestId('profile-nickname')).toHaveText(`新讀者${suffix}`)

  // Log out from the user menu.
  await page.getByTestId('user-menu').hover()
  await page.getByText('登出', { exact: true }).click()
  await expect(page.getByRole('button', { name: '登入' })).toBeVisible()

  // Protected pages redirect to login and come back afterwards.
  await page.goto('/bookshelf')
  await expect(page).toHaveURL(/\/login\?redirect=/)
  await page.getByPlaceholder('輸入帳號或電子郵件').fill(username)
  await page.getByPlaceholder('輸入密碼').fill(password)
  await page.getByRole('button', { name: '登入' }).click()
  await expect(page).toHaveURL(/\/bookshelf$/)
  await expect(page.getByRole('heading', { name: '我的書架' })).toBeVisible()
})

test('forgot password sends a link and reset rejects a bad token', async ({ page }) => {
  await page.goto('/login')
  await page.getByRole('link', { name: '忘記密碼？' }).click()
  await expect(page).toHaveURL(/\/forgot-password$/)
  await page.getByPlaceholder('your@email.com').fill(`nobody${uniqueSuffix()}@example.com`)
  await page.getByRole('button', { name: '寄送重設連結' }).click()
  await expect(page.getByText('請檢查你的信箱')).toBeVisible()

  await page.goto('/reset-password')
  await expect(page.getByTestId('reset-error')).toContainText('重設連結不完整')

  await page.goto('/reset-password?token=not-a-real-token')
  await page.getByPlaceholder('至少 8 個字元').fill('new-password-1')
  await page.getByPlaceholder('再次輸入新密碼').fill('new-password-1')
  await page.getByRole('button', { name: '重設密碼' }).click()
  await expect(page.getByTestId('reset-error')).toContainText('重設連結無效或已過期')
})

test('wrong password shows an error', async ({ page }) => {
  // Uses the login quota once more; still within 5/minute for this file.
  await page.goto('/login')
  await page.getByPlaceholder('輸入帳號或電子郵件').fill(`nobody${uniqueSuffix()}`)
  await page.getByPlaceholder('輸入密碼').fill('definitely-wrong')
  await page.getByRole('button', { name: '登入' }).click()
  await expect(page.getByText('帳號或密碼錯誤')).toBeVisible()
  await expect(page).toHaveURL(/\/login/)
})
