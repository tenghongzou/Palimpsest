import { chromium, type FullConfig } from '@playwright/test'
import fs from 'node:fs'
import { ADMIN, ADMIN_STATE, AUTH_DIR, USER_INFO, USER_STATE, loginViaUi, uniqueSuffix, type UserInfo } from './helpers'

// Creates one admin session and one fresh reader session for all specs, so the
// rate limited auth endpoints are hit only a couple of times per run.
export default async function globalSetup(config: FullConfig) {
  const { baseURL, launchOptions } = config.projects[0].use
  fs.mkdirSync(AUTH_DIR, { recursive: true })
  const browser = await chromium.launch(launchOptions)
  try {
    const adminPage = await browser.newPage({ baseURL })
    await loginViaUi(adminPage, ADMIN.login, ADMIN.password)
    await adminPage.context().storageState({ path: ADMIN_STATE })

    const suffix = uniqueSuffix()
    const user: UserInfo = { username: `e2e${suffix}`, email: `e2e${suffix}@example.com`, password: 'e2e-password-1' }
    const page = await browser.newPage({ baseURL })
    await page.goto('/register')
    await page.getByPlaceholder('4-20 個字元').fill(user.username)
    await page.getByPlaceholder('顯示名稱').fill(`讀者${suffix}`)
    await page.getByPlaceholder('your@email.com').fill(user.email)
    await page.getByPlaceholder('至少 8 個字元').fill(user.password)
    await page.getByPlaceholder('再次輸入密碼').fill(user.password)
    await page.getByRole('button', { name: '註冊' }).click()
    await page.waitForURL(url => !url.pathname.startsWith('/register'))
    await page.context().storageState({ path: USER_STATE })
    fs.writeFileSync(USER_INFO, JSON.stringify(user))
  }
  finally {
    await browser.close()
  }
}
