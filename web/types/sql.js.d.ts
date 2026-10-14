// Minimal typings for the parts of sql.js we use (the package ships none).
declare module 'sql.js' {
  import type { SqlDatabase } from '~/utils/localDb'

  export interface SqlJsStatic {
    Database: new (data?: ArrayLike<number> | Uint8Array | null) => SqlDatabase
  }

  export interface SqlJsConfig {
    locateFile?: (file: string) => string
  }

  export default function initSqlJs(config?: SqlJsConfig): Promise<SqlJsStatic>
}
