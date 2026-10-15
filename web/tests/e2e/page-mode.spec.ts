import { type Page } from '@playwright/test'
import { test, expect, USER_STATE, api, chaptersOf, pickNovel, ensureQuota } from './helpers'

test.use({ storageState: USER_STATE, viewport: { width: 1000, height: 700 } })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

/** Seed chapters are short; serve longer text so a chapter spans several pages. */
async function lengthenChapters(page: Page) {
  const text = Array.from({ length: 30 }, (_, i) =>
    `第${i + 1}段。海霧終年不散的港口，燈塔看守人每晚都會收到一封沒有寄件人的信。信紙泛黃，字跡細瘦，像是用很久以前的墨水寫成。`,
  ).join('\n\n')
  await page.route('**/api/v1/chapters/*', async (route) => {
    if (route.request().method() !== 'GET') return route.fallback()
    const response = await route.fetch()
    const body = await response.json() as { data?: { content?: string } }
    if (body.data?.content) body.data.content = text
    await route.fulfill({ response, json: body })
  })
}

const DEFAULT_SETTINGS = {
  font_size: 18, line_height: 1.8, letter_spacing: 0, margin: 16, font_family: 'system', theme: 'white',
  reading_mode: 'scroll', page_animation: 'slide', brightness: 100, keep_screen_on: true, auto_chapter: true,
}

async function pageNumbers(page: Page): Promise<[number, number]> {
  const text = await page.getByTestId('reader-page-indicator').textContent() ?? ''
  const m = text.match(/(\d+)\s*\/\s*(\d+)/)
  if (!m) throw new Error(`no page indicator: ${text}`)
  return [Number(m[1]), Number(m[2])]
}

test('page mode: switch on, turn pages by tap, key and wheel, cross chapters and restore progress', async ({ page }) => {
  const novel = await pickNovel(page, 2)
  const [first, second] = await chaptersOf(page, novel.id)
  await lengthenChapters(page)
  try {
    await page.goto(`/read/${first.id}`)
    await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()

    // Switch to page mode in the settings drawer; the animation choice appears with it.
    await page.getByTestId('reader-paragraphs').locator('p').first().click()
    await page.getByTestId('toolbar-settings').click()
    const form = page.getByTestId('reader-settings-form')
    await expect(form.getByTestId('page-animation-setting')).toHaveCount(0)
    await form.getByText('翻頁', { exact: true }).click()
    await expect(form.getByTestId('page-animation-setting')).toBeVisible()
    await form.getByTestId('page-animation-slide').click()
    await page.keyboard.press('Escape')
    await expect(page.getByTestId('reader-settings-form')).toBeHidden()

    const indicator = page.getByTestId('reader-page-indicator')
    await expect(indicator).toHaveText(/^\s*1 \/ \d+\s*$/)
    const [, total] = await pageNumbers(page)
    expect(total).toBeGreaterThan(3)

    const { width, height } = page.viewportSize()!
    // Right third turns forward, left third back, the middle toggles the toolbar.
    await page.mouse.click(width * 0.85, height / 2)
    await expect(indicator).toHaveText(new RegExp(`^\\s*2 / ${total}\\s*$`))
    await page.keyboard.press('ArrowRight')
    await expect(indicator).toHaveText(new RegExp(`^\\s*3 / ${total}\\s*$`))
    await page.keyboard.press('PageUp')
    await expect(indicator).toHaveText(new RegExp(`^\\s*2 / ${total}\\s*$`))
    await page.mouse.click(width * 0.1, height / 2)
    await expect(indicator).toHaveText(new RegExp(`^\\s*1 / ${total}\\s*$`))
    await page.mouse.move(width / 2, height / 2)
    await page.mouse.wheel(0, 120)
    await expect(indicator).toHaveText(new RegExp(`^\\s*2 / ${total}\\s*$`))
    await page.keyboard.press('Space')
    await expect(indicator).toHaveText(new RegExp(`^\\s*3 / ${total}\\s*$`))

    // Past the last page: the next chapter opens on its first page...
    for (let i = 3; i < total; i++) await page.keyboard.press('ArrowRight')
    await expect(indicator).toHaveText(new RegExp(`^\\s*${total} / ${total}\\s*$`))
    await page.keyboard.press('ArrowRight')
    await expect(page).toHaveURL(new RegExp(`/read/${second.id}`))
    await expect(page.getByRole('heading', { name: second.title })).toBeAttached()
    await expect(indicator).toHaveText(/^\s*1 \/ \d+\s*$/)
    // ...and going back from its first page opens the previous chapter on its last page.
    await page.keyboard.press('ArrowLeft')
    await expect(page).toHaveURL(new RegExp(`/read/${first.id}`))
    await expect(indicator).toHaveText(new RegExp(`^\\s*${total} / ${total}\\s*$`))

    // Read to page 3 and leave: "continue reading" reopens that page.
    await page.goto(`/read/${first.id}`)
    await expect(indicator).toHaveText(/^\s*1 \/ \d+\s*$/)
    await page.keyboard.press('ArrowRight')
    await page.keyboard.press('ArrowRight')
    await expect(indicator).toHaveText(new RegExp(`^\\s*3 / ${total}\\s*$`))
    await page.mouse.click(width / 2, height / 2)
    await expect(page.getByTestId('reader-back')).toBeInViewport()
    await page.getByTestId('reader-back').click()
    await expect(page).toHaveURL(new RegExp(`/novel/${novel.id}`))
    await expect(page.getByTestId('start-reading')).toHaveText('繼續閱讀')
    await page.getByTestId('start-reading').click()
    await expect(page).toHaveURL(new RegExp(`/read/${first.id}\\?p=\\d+`))
    await expect(indicator).toHaveText(new RegExp(`^\\s*3 / ${total}\\s*$`))
  }
  finally {
    // Other specs expect scroll mode.
    await api(page, 'PUT', '/users/me/reading-settings', DEFAULT_SETTINGS).catch(() => {})
  }
})

test('page mode honours prefers-reduced-motion and the curl animation turns pages', async ({ page }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)
  await lengthenChapters(page)
  await api(page, 'PUT', '/users/me/reading-settings', { ...DEFAULT_SETTINGS, reading_mode: 'page', page_animation: 'curl' })
  try {
    await page.goto(`/read/${first.id}`)
    const pager = page.getByTestId('reader-pager')
    const indicator = page.getByTestId('reader-page-indicator')
    await expect(indicator).toHaveText(/^\s*1 \/ \d+\s*$/)
    await expect(pager).toHaveAttribute('data-animation', 'curl')

    // Drag the bottom-right corner across: the page curls and turns.
    const { width, height } = page.viewportSize()!
    await page.mouse.move(width - 10, height - 20)
    await page.mouse.down()
    await page.mouse.move(width * 0.4, height - 120, { steps: 10 })
    await expect(page.locator('.curl-flap')).toBeVisible()
    await page.mouse.up()
    await expect(indicator).toHaveText(/^\s*2 \/ \d+\s*$/)
    await expect(page.locator('.curl-flap')).toHaveCount(0)

    await page.emulateMedia({ reducedMotion: 'reduce' })
    await expect(pager).toHaveAttribute('data-animation', 'none')
    await page.keyboard.press('ArrowRight')
    await expect(indicator).toHaveText(/^\s*3 \/ \d+\s*$/)
  }
  finally {
    await api(page, 'PUT', '/users/me/reading-settings', DEFAULT_SETTINGS).catch(() => {})
  }
})
