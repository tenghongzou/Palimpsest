import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { buildMigrationsModule } from '../../../scripts/sync-sqlite-schema.mjs'

describe('generated SQLite migrations', () => {
  it('match shared/sqlite-schema (run `pnpm sync:schema` if this fails)', () => {
    const generated = readFileSync(fileURLToPath(new URL('../../../utils/sqliteMigrations.ts', import.meta.url)), 'utf8')
    expect(generated.replace(/\r\n/g, '\n')).toBe(buildMigrationsModule())
  })
})
