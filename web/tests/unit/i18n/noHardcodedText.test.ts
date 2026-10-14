// UI copy belongs in i18n/locales/*.json. This scans components, pages,
// layouts and composables for CJK text outside comments.
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const ROOT = fileURLToPath(new URL('../../../', import.meta.url))
const DIRS = ['app.vue', 'components', 'pages', 'layouts', 'composables', 'plugins', 'middleware', 'stores']

/**
 * Legitimate CJK outside the locale files, by file: language names shown in
 * their own script, and content-parsing patterns (not UI copy).
 */
const ALLOWED: Record<string, RegExp[]> = {}

const CJK = /[㐀-鿿豈-﫿　-〿！-～]/

function files(path: string): string[] {
  const full = join(ROOT, path)
  if (statSync(full).isFile()) return [full]
  return readdirSync(full).flatMap(name => files(join(path, name)))
}

/** Drops comments (HTML, block and line) so explanatory notes may use any language. */
function stripComments(source: string): string {
  return source
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:'"`])\/\/.*$/gm, '$1')
}

describe('no hard-coded UI text', () => {
  const sources = DIRS.flatMap(files).filter(f => /\.(vue|ts)$/.test(f))

  it('scans the UI sources', () => {
    expect(sources.length).toBeGreaterThan(50)
  })

  it('keeps CJK copy in the locale files', () => {
    const offenders: string[] = []
    for (const file of sources) {
      const rel = relative(ROOT, file).replace(/\\/g, '/')
      const allowed = ALLOWED[rel] ?? []
      stripComments(readFileSync(file, 'utf8')).split('\n').forEach((line, i) => {
        if (!CJK.test(line)) return
        if (allowed.some(re => re.test(line))) return
        offenders.push(`${rel}:${i + 1}: ${line.trim()}`)
      })
    }
    expect(offenders).toEqual([])
  })
})
