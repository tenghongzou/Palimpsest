import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import initSqlJs from 'sql.js'
import type { SqlDatabase } from '~/utils/localDb'

const require = createRequire(import.meta.url)

export interface SqlBuild {
  name: string
  open: () => Promise<{ Database: new (data?: Uint8Array) => SqlDatabase }>
}

/**
 * The browser bundle of sql.js is minified differently from the Node one
 * (exec() result keys are mangled, run() drops parameters), so local DB code
 * is tested against both.
 */
export const SQL_BUILDS: SqlBuild[] = [
  { name: 'node build', open: () => initSqlJs() },
  {
    name: 'browser build',
    open: () => require('sql.js/dist/sql-wasm-browser.js')({
      wasmBinary: readFileSync(require.resolve('sql.js/dist/sql-wasm-browser.wasm')),
    }),
  },
]
