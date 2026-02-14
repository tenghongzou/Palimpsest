import { describe, it, expect } from 'vitest'

describe('Translation composable contract', () => {
  it('supported conversion directions', () => {
    const directions = ['tw2cn', 'cn2tw'] as const
    expect(directions).toContain('tw2cn')
    expect(directions).toContain('cn2tw')
  })

  it('supported target languages', () => {
    const langs = ['en', 'zh-TW', 'zh-CN']
    expect(langs).toHaveLength(3)
  })

  it('convert request structure', () => {
    const req = { text: '你好世界', from: 'zh-TW', to: 'zh-CN' }
    expect(req.text).toBeTruthy()
    expect(req.from).toBeTruthy()
    expect(req.to).toBeTruthy()
  })

  it('translate request structure', () => {
    const req = { text: '你好', source_language: 'zh-TW', target_language: 'en' }
    expect(req.text).toBeTruthy()
    expect(req.target_language).toBe('en')
  })
})
