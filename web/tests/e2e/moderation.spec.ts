import { test, expect, ADMIN_STATE, USER_STATE, api, chaptersOf, ensureQuota, pickNovel, uniqueSuffix } from './helpers'

test.use({ storageState: ADMIN_STATE })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

test('dashboard shows trends, top novels and categories', async ({ page }) => {
  const trends = page.waitForResponse(r => r.url().includes('/admin/stats/trends') && r.url().includes('days=30'))
  await page.goto('/admin')
  expect((await trends).ok()).toBe(true)

  await expect(page.getByTestId('admin-stats').getByText('待審核內容')).toBeVisible()
  const panel = page.getByTestId('admin-trends')
  // Either charts or the "no activity" empty state, depending on the data.
  await expect(panel.getByTestId('trend-reads').or(panel.getByText('這段期間沒有活動資料'))).toBeVisible()
  if (await panel.getByTestId('trend-reads').isVisible()) {
    await expect(panel.getByTestId('returning-rate')).toContainText('%')
    await expect(panel.getByTestId('trend-reads').locator('svg')).toBeVisible()
  }

  const week = page.waitForResponse(r => r.url().includes('/admin/stats/trends') && r.url().includes('days=7'))
  await panel.getByTestId('trend-range').getByText('近 7 天').click()
  expect((await week).ok()).toBe(true)

  const top = page.getByTestId('admin-top-novels')
  await expect(top).toBeVisible()
  const today = page.waitForResponse(r => r.url().includes('/admin/stats/top-novels') && r.url().includes('days=1'))
  await top.getByText('今日', { exact: true }).click()
  expect((await today).ok()).toBe(true)
  await expect(page.getByTestId('admin-categories')).toBeVisible()
})

test('a blocked term holds a comment for moderation until an admin approves it', async ({ page, browser }) => {
  const term = `e2e禁詞${uniqueSuffix()}`
  let termId: number | undefined
  let commentId: string | undefined
  const readerContext = await browser.newContext({ storageState: USER_STATE })
  const reader = await readerContext.newPage()
  // Signed out: pending content must never be listed for anyone but its author.
  const guestContext = await browser.newContext({ storageState: { cookies: [], origins: [] } })
  const guest = await guestContext.newPage()

  try {
    // Add the term from the terms tab; a second add is rejected.
    await page.goto('/admin/moderation?tab=terms')
    await expect(page.getByTestId('terms-help')).toBeVisible()
    await page.getByPlaceholder('輸入要檢查的詞語').fill(term)
    await page.getByRole('button', { name: '新增', exact: true }).click()
    await expect(page.getByTestId('terms-table').getByText(term, { exact: true })).toBeVisible()
    termId = (await api<{ id: number, term: string }[]>(page, 'GET', '/admin/moderation/terms')).find(x => x.term === term)?.id
    await page.getByPlaceholder('輸入要檢查的詞語').fill(term)
    await page.getByRole('button', { name: '新增', exact: true }).click()
    await expect(page.getByText(`「${term}」已存在`)).toBeVisible()

    // The reader's comment is held back: a notice, and only its author sees it, tagged 審核中.
    const novel = await pickNovel(reader, 1)
    const [first] = await chaptersOf(reader, novel.id)
    const text = `E2E 審核留言 ${term}`
    await reader.goto(`/read/${first!.id}`)
    await expect(reader.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
    await reader.getByTestId('reader-comments').click()
    const panel = reader.getByTestId('chapter-comments')
    await panel.getByTestId('comment-input').locator('textarea').fill(text)
    const posted = reader.waitForResponse(r => r.url().endsWith(`/chapters/${first!.id}/comments`) && r.request().method() === 'POST')
    await panel.getByTestId('comment-submit').click()
    const body = await (await posted).json() as { data: { id: string, status: string } }
    commentId = body.data.id
    expect(body.data.status).toBe('pending')
    await expect(reader.getByText('已送出，內容將在審核後公開')).toBeVisible()
    const own = panel.getByTestId('comment-item').filter({ hasText: text })
    await expect(own).toBeVisible()
    await expect(own.getByTestId('pending-tag')).toHaveText('審核中')
    await expect(own.getByTestId('comment-like')).toHaveCount(0)
    await expect(own.getByTestId('comment-reply')).toHaveCount(0)
    await expect(own.getByTestId('comment-report')).toHaveCount(0)

    // After a reload the list endpoint still returns it to the author.
    await reader.reload()
    await reader.getByTestId('reader-comments').click()
    await expect(reader.getByTestId('chapter-comments').getByTestId('comment-item').filter({ hasText: text }).getByTestId('pending-tag')).toBeVisible()

    // A signed-out visitor does not see it.
    const guestList = guest.waitForResponse(r => r.url().includes(`/chapters/${first!.id}/comments?`) && r.request().method() === 'GET')
    await guest.goto(`/read/${first!.id}`)
    await expect(guest.getByTestId('reader-paragraphs').locator('p').first()).toBeVisible()
    await guest.getByTestId('reader-comments').click()
    expect((await guestList).ok()).toBe(true)
    await expect(guest.getByTestId('chapter-comments')).toBeVisible()
    await expect(guest.getByTestId('chapter-comments').getByText(text)).toHaveCount(0)

    // The admin finds it in the pending queue with the matched term and approves it.
    await page.goto('/admin/moderation')
    await page.getByTestId('moderation-type').getByText('留言', { exact: true }).click()
    const item = page.getByTestId(`moderation-item-${commentId}`)
    await expect(item).toBeVisible()
    await expect(item.getByTestId('moderation-flag').filter({ hasText: term })).toBeVisible()
    await item.getByRole('button', { name: '通過' }).click()
    await expect(item).toHaveCount(0)

    // Now it is public, without the tag.
    await reader.reload()
    await reader.getByTestId('reader-comments').click()
    const published = reader.getByTestId('chapter-comments').getByTestId('comment-item').filter({ hasText: text })
    await expect(published).toBeVisible()
    await expect(published.getByTestId('pending-tag')).toHaveCount(0)
    await guest.reload()
    await guest.getByTestId('reader-comments').click()
    await expect(guest.getByTestId('chapter-comments').getByTestId('comment-item').filter({ hasText: text })).toBeVisible()
  }
  finally {
    if (commentId) await api(reader, 'DELETE', `/comments/${commentId}`).catch(() => {})
    await readerContext.close()
    await guestContext.close()
    if (termId !== undefined) await api(page, 'DELETE', `/admin/moderation/terms/${termId}`).catch(() => {})
  }
})

test('moderation tabs and the reviews filter load', async ({ page }) => {
  await page.goto('/admin/moderation')
  await expect(page.getByRole('heading', { name: '內容審核' })).toBeVisible()
  await expect(page.getByTestId('moderation-list').or(page.getByText('目前沒有待審核的內容'))).toBeVisible()

  await page.locator('.n-tabs-tab', { hasText: '已標記' }).click()
  await expect(page).toHaveURL(/tab=flagged/)
  await expect(page.getByTestId('moderation-list').or(page.getByText('沒有被標記的內容'))).toBeVisible()

  await page.goto('/admin/reviews')
  await page.locator('.n-select').first().click()
  await expect(page.locator('.n-base-select-option', { hasText: '待審核' })).toBeVisible()
})
