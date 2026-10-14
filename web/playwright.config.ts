import { defineConfig } from '@playwright/test'

// Set PLAYWRIGHT_BASE_URL to test an already running server (no webServer is
// started then). PLAYWRIGHT_CHROMIUM_PATH points at a specific Chromium build.
const externalBaseURL = process.env.PLAYWRIGHT_BASE_URL
const baseURL = externalBaseURL || 'http://localhost:3000'
const executablePath = process.env.PLAYWRIGHT_CHROMIUM_PATH || undefined

export default defineConfig({
  testDir: './tests/e2e',
  // Generous: specs may wait for API rate-limit quota (see ensureQuota).
  timeout: 150_000,
  expect: { timeout: 15_000 },
  // Auth endpoints are rate limited per IP, so specs share sessions created once
  // in global setup and run serially against the one backend.
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  globalSetup: './tests/e2e/global-setup.ts',
  reporter: [['list']],
  use: {
    baseURL,
    headless: true,
    // Specs match zh-TW copy: pin the browser language (the UI locale is detected
    // from it on first visit). i18n.spec.ts overrides it per test.
    locale: 'zh-TW',
    // Keep the service worker out of the way of request mocking (page.route) and
    // offline emulation; pwa.spec.ts opts back in.
    serviceWorkers: 'block',
    trace: 'retain-on-failure',
    launchOptions: executablePath ? { executablePath } : {},
  },
  webServer: externalBaseURL
    ? undefined
    : {
        command: 'npx --no-install nuxi preview',
        url: baseURL,
        reuseExistingServer: !process.env.CI,
        timeout: 180_000,
      },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
})
