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
