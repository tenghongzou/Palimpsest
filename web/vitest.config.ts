import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  resolve: {
    alias: {
      '~': fileURLToPath(new URL('./', import.meta.url)),
    },
  },
  test: {
    passWithNoTests: true,
    // Playwright specs live in tests/e2e and run with `playwright test`.
    include: ['tests/unit/**/*.test.ts'],
  },
})
