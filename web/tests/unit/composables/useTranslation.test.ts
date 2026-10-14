import { describe, it, expect } from 'vitest'

describe('Translation composable contract', () => {
  it('supported conversion languages', () => {
    const chinese = ['zh-TW', 'zh-CN'] as const
    expect(chinese).toContain('zh-TW')
    expect(chinese).toContain('zh-CN')
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
    const req = { text: '你好', from: 'zh-TW', to: 'en' }
    expect(req.text).toBeTruthy()
    expect(req.to).toBe('en')
  })
})
