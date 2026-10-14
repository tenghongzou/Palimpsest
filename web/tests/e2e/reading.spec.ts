import { expect, test, type Page } from '@playwright/test'
import { USER_STATE, api, chaptersOf, pickNovel, uniqueSuffix, POLL, ensureQuota } from './helpers'

test.use({ storageState: USER_STATE })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

/** Shows the reader toolbar (it toggles when the text is clicked). */
async function showToolbar(page: Page) {
  const toolbar = page.getByTestId('toolbar-bookmarks')
  const onScreen = () => toolbar.evaluate(el => el.getBoundingClientRect().top < window.innerHeight)
  if (!(await onScreen())) {
    await page.getByTestId('reader-paragraphs').locator('p').first().click()
  }
  await expect(toolbar).toBeInViewport()
}

test('browse home, open a novel, read and go to the next chapter', async ({ page }) => {
  const novel = await pickNovel(page, 2)
  const chapters = await chaptersOf(page, novel.id)

  await page.goto('/')
  await expect(page.getByRole('heading', { name: '熱門推薦' })).toBeVisible()
  await expect(page.getByTestId('novel-card').first()).toBeVisible()

  await page.goto(`/novel/${novel.id}`)
  await expect(page.getByTestId('novel-title')).toHaveText(novel.title)
  await expect(page.getByTestId('chapter-link')).toHaveCount(chapters.length)

  // Start at chapter 1 (other specs may already have saved progress for this novel).
  const start = page.getByTestId('start-reading')
  await expect(start).toBeEnabled()
  await page.waitForLoadState('networkidle')
  const fromStart = page.getByTestId('read-from-start')
  if (await fromStart.isVisible()) await fromStart.click()
  else await start.click()
  await expect(page).toHaveURL(new RegExp(`/read/${chapters[0].id}`))
  await expect(page.getByRole('heading', { name: chapters[0].title })).toBeVisible()
  await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()

  await page.getByTestId('reader-next').click()
  await expect(page).toHaveURL(new RegExp(`/read/${chapters[1].id}`))
  await expect(page.getByRole('heading', { name: chapters[1].title })).toBeVisible()
  await expect(page.getByTestId('reader-prev')).toBeEnabled()

  // Progress reaches the server, so the novel page offers to continue.
  await expect.poll(async () => (await api<{ chapter_id: string }>(page, 'GET', `/reading-progress/${novel.id}`).catch(() => null))?.chapter_id, POLL)
    .toBe(chapters[1].id)
  await page.goto(`/novel/${novel.id}`)
  await expect(page.getByTestId('start-reading')).toHaveText('繼續閱讀')
  await expect(page.getByTestId('resume-hint')).toContainText(chapters[1].title)
  await page.getByTestId('start-reading').click()
  await expect(page).toHaveURL(new RegExp(`/read/${chapters[1].id}`))

  // The history page lists the chapters that were opened.
  await page.goto('/profile/history')
  await expect(page.getByTestId('history-item').first()).toContainText(novel.title)
})

test('bookmarks: add with a note, list, jump, delete; and add while offline', async ({ page, context }) => {
  const novel = await pickNovel(page, 2)
  const [first] = await chaptersOf(page, novel.id)
  const note = `書籤備註${uniqueSuffix()}`

  await page.goto(`/read/${first.id}`)
  await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
  await showToolbar(page)
  await page.getByTestId('toolbar-bookmarks').click()
  await page.getByTestId('bookmark-note').locator('textarea').fill(note)
  await page.getByTestId('bookmark-add').click()
  const item = page.getByTestId('bookmark-item').filter({ hasText: note })
  await expect(item).toBeVisible()

  // It is synced to the server.
  await expect.poll(async () => (await api<{ note?: string }[]>(page, 'GET', `/bookmarks?novel_id=${novel.id}`)).some(b => b.note === note), POLL)
    .toBe(true)

  // The profile page lists it and jumps back into the chapter.
  await page.goto('/profile/bookmarks')
  const listed = page.getByTestId('bookmark-item').filter({ hasText: note })
  await expect(listed).toBeVisible()
  await listed.getByText(first.title).click()
  await expect(page).toHaveURL(new RegExp(`/read/${first.id}\\?p=\\d+`))

  // Offline: the bookmark is stored locally and uploaded when back online.
  const offlineNote = `離線書籤${uniqueSuffix()}`
  await context.setOffline(true)
  await showToolbar(page)
  await page.getByTestId('toolbar-bookmarks').click()
  await page.getByTestId('bookmark-note').locator('textarea').fill(offlineNote)
  await page.getByTestId('bookmark-add').click()
  const offlineItem = page.getByTestId('bookmark-item').filter({ hasText: offlineNote })
  await expect(offlineItem).toContainText('尚未同步')
  await context.setOffline(false)
  await expect.poll(
    async () => (await api<{ note?: string }[]>(page, 'GET', `/bookmarks?novel_id=${novel.id}`)).some(b => b.note === offlineNote),
    POLL,
  ).toBe(true)

  // Delete both from the drawer.
  await page.reload()
  await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
  await showToolbar(page)
  await page.getByTestId('toolbar-bookmarks').click()
  for (const text of [note, offlineNote]) {
    const row = page.getByTestId('bookmark-item').filter({ hasText: text })
    await row.getByRole('button', { name: '刪除' }).click()
    await page.locator('.n-popconfirm').getByRole('button', { name: '確定' }).click()
    await expect(row).toHaveCount(0)
  }
  await expect.poll(async () => (await api<{ note?: string }[]>(page, 'GET', `/bookmarks?novel_id=${novel.id}`))
    .filter(b => b.note === note || b.note === offlineNote).length, POLL).toBe(0)
})

test('chapter comments: post, like, reply and delete', async ({ page }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)
  const text = `E2E 留言 ${uniqueSuffix()}`

  await page.goto(`/read/${first.id}`)
  await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
  await page.getByTestId('reader-comments').click()
  const panel = page.getByTestId('chapter-comments')
  await panel.getByTestId('comment-input').locator('textarea').fill(text)
  await panel.getByTestId('comment-submit').click()
  const comment = panel.getByTestId('comment-item').filter({ hasText: text })
  await expect(comment).toBeVisible()

  await comment.getByTestId('comment-like').first().click()
  await expect(comment.getByTestId('comment-like').first()).toContainText('已讚 1')

  await comment.getByRole('button', { name: '回覆' }).first().click()
  await panel.getByTestId('comment-input').locator('textarea').fill('同意！')
  await panel.getByTestId('comment-submit').click()
  await expect(comment.getByTestId('comment-content').filter({ hasText: '同意！' })).toBeVisible()

  await comment.getByRole('button', { name: '刪除' }).first().click()
  await page.locator('.n-popconfirm').getByRole('button', { name: '確定' }).click()
  await expect(comment).toHaveCount(0)
})

test('translation shows a friendly message when English is unavailable', async ({ page }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)

  await page.goto(`/read/${first.id}`)
  await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
  await showToolbar(page)
  await page.getByTestId('toolbar-translate').click()
  await page.getByTestId('translate-lang-en').click()

  const translated = page.waitForResponse(r => r.url().includes('/translation/chapter'))
  await page.getByTestId('translate-submit').click()
  const response = await translated
  if (response.status() === 503) {
    await expect(page.getByTestId('translate-error')).toContainText('目前沒有可用的英文翻譯服務')
  }
  else {
    expect(response.status()).toBe(200)
    await expect(page.getByText('目前顯示翻譯內容')).toBeVisible()
  }
})

test('reading settings change the reader and persist to the account', async ({ page }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)

  await page.goto(`/read/${first.id}`)
  await expect(page.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
  await showToolbar(page)
  await page.getByTestId('toolbar-settings').click()
  await page.getByTestId('theme-sepia').click()
  await expect(page.locator('.reader-layout')).toHaveCSS('background-color', 'rgb(245, 240, 224)')

  await expect.poll(async () => (await api<{ theme: string }>(page, 'GET', '/users/me/reading-settings')).theme, POLL)
    .toBe('sepia')

  // Reset so other specs start from defaults.
  await page.getByRole('button', { name: '重置為預設' }).click()
  await expect.poll(async () => (await api<{ theme: string }>(page, 'GET', '/users/me/reading-settings')).theme, POLL)
    .toBe('white')
})
