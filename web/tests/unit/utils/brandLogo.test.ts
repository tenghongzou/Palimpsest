import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { BRAND_LAYOUTS, MARK_GRADIENT, MARK_SHAPES, WORDMARK_COLOR, WORDMARK_PATH } from '~/utils/brandLogo'

function brand(name: string): string {
  return readFileSync(fileURLToPath(new URL(`../../../../shared/brand/${name}`, import.meta.url)), 'utf8')
}

function viewBox(svg: string): number[] {
  return svg.match(/viewBox="([^"]+)"/)![1]!.split(' ').map(Number)
}

describe('BrandLogo data (utils/brandLogo.ts) matches shared/brand', () => {
  it('uses the wordmark outlines from wordmark.svg', () => {
    const svg = brand('wordmark.svg')
    expect(svg).toContain('fill="currentColor"')
    expect(svg).toContain(`d="${WORDMARK_PATH}"`)
  })

  it('draws the mark from logo-mark.svg', () => {
    const svg = brand('logo-mark.svg')
    for (const shape of MARK_SHAPES) expect(svg).toContain(`fill="${shape.fill}"${shape.evenodd ? ' fill-rule="evenodd"' : ''} d="${shape.d}"`)
    for (const stop of MARK_GRADIENT) expect(svg).toContain(`stop-color="${stop}"`)
    expect(viewBox(svg)).toEqual([0, 0, BRAND_LAYOUTS.mark.width, BRAND_LAYOUTS.mark.height])
  })

  it.each([
    ['horizontal', 'logo-horizontal.svg', 'light'],
    ['horizontal', 'logo-horizontal-dark.svg', 'dark'],
    ['stacked', 'logo-stacked.svg', 'light'],
    ['stacked', 'logo-stacked-dark.svg', 'dark'],
  ] as const)('lays out %s like %s', (variant, file, tone) => {
    const svg = brand(file)
    const layout = BRAND_LAYOUTS[variant]
    expect(viewBox(svg)).toEqual([0, 0, layout.width, layout.height])
    expect(svg).toContain(`<path fill="${WORDMARK_COLOR[tone]}" transform="${layout.wordmark}" d="${WORDMARK_PATH}"/>`)
    if (layout.markX) expect(svg).toContain(`<g transform="translate(${layout.markX.toFixed(2)} 0)">`)
  })
})
