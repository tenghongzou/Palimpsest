import { test, expect, ADMIN_STATE, USER_STATE, api, pickNovel, uniqueSuffix, ensureQuota } from './helpers'

test.use({ storageState: USER_STATE })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

test('write, edit and delete a review', async ({ page }) => {
  const novel = await pickNovel(page, 1)
  const title = `E2E 書評 ${uniqueSuffix()}`

  // A fresh reader has not reviewed anything; clean up leftovers just in case.
  const me = await api<{ id: string }>(page, 'GET', '/users/me')
  const existing = await api<{ items: { id: string, user_id: string }[] }>(page, 'GET', `/novels/${novel.id}/reviews?page_size=100`)
  for (const r of existing.items.filter(r => r.user_id === me.id)) await api(page, 'DELETE', `/reviews/${r.id}`)

  await page.goto(`/novel/${novel.id}`)
  const reviews = page.getByTestId('novel-reviews')
  await reviews.getByTestId('review-write').click()
  const editor = reviews.getByTestId('review-editor')
  // Four stars: click the fourth star.
  await editor.getByTestId('review-rating').locator('.n-rate__item').nth(3).click()
  await editor.getByTestId('review-title').locator('input').fill(title)
  await editor.getByTestId('review-content').locator('textarea').fill('劇情緊湊，角色立體。')
  await editor.getByTestId('review-save').click()

  const mine = reviews.getByTestId('review-item').filter({ hasText: title })
  await expect(mine).toBeVisible()
  await expect(mine).toContainText('我的書評')
  await expect(reviews.getByTestId('review-write')).toHaveCount(0)

  // Edit it.
  await mine.getByTestId('review-edit').click()
  await editor.getByTestId('review-title').locator('input').fill(`${title}（修改）`)
  await editor.getByTestId('review-save').click()
  await expect(reviews.getByTestId('review-item-title').filter({ hasText: `${title}（修改）` })).toBeVisible()

  // Like and unlike.
  const edited = reviews.getByTestId('review-item').filter({ hasText: `${title}（修改）` })
  await edited.getByTestId('review-like').click()
  await expect(edited.getByTestId('review-like')).toContainText('已讚 1')
  await edited.getByTestId('review-like').click()
  await expect(edited.getByTestId('review-like')).not.toContainText('已讚')

  // Sorting by popularity reloads the list.
  await reviews.getByText('最熱', { exact: true }).click()
  await expect(edited).toBeVisible()

  // Delete it.
  await edited.getByTestId('review-delete').click()
  await page.locator('.n-popconfirm').getByRole('button', { name: '確定' }).click()
  await expect(edited).toHaveCount(0)
  await expect(reviews.getByTestId('review-write')).toBeVisible()
})

test('report another reader\'s review', async ({ page, browser }) => {
  const novel = await pickNovel(page, 1)
  // The admin writes a review for the reader to report (removed afterwards).
  const adminContext = await browser.newContext({ storageState: ADMIN_STATE })
  const admin = await adminContext.newPage()
  const adminMe = await api<{ id: string }>(admin, 'GET', '/users/me')
  const existing = await api<{ items: { id: string, user_id: string }[] }>(admin, 'GET', `/novels/${novel.id}/reviews?page_size=100`)
  const old = existing.items.find(r => r.user_id === adminMe.id)
  const review = old ?? await api<{ id: string }>(admin, 'POST', `/novels/${novel.id}/reviews`, {
    title: `E2E 待檢舉書評 ${uniqueSuffix()}`,
    content: '這是端對端測試建立的書評。',
    rating: 3,
  })

  try {
    await page.goto(`/novel/${novel.id}`)
    const reviews = page.getByTestId('novel-reviews')
    await reviews.getByTestId('review-report').first().click()
    await page.getByRole('dialog').getByText('劇透').click()
    await page.getByRole('dialog').getByPlaceholder('描述問題，協助管理員判斷').fill('E2E 測試檢舉')
    await page.getByTestId('report-submit').click()
    await expect(page.getByText('已送出檢舉，感謝你的回報')).toBeVisible()

    // The admin sees it among pending reports.
    const reports = await api<{ items: { description?: string }[] }>(admin, 'GET', '/admin/reports?status=pending&page_size=100')
    expect(reports.items.some(r => r.description === 'E2E 測試檢舉')).toBe(true)
  }
  finally {
    const pending = await api<{ items: { id: string, description?: string }[] }>(admin, 'GET', '/admin/reports?status=pending&page_size=100').catch(() => ({ items: [] }))
    for (const r of pending.items.filter(r => r.description === 'E2E 測試檢舉')) {
      await api(admin, 'PUT', `/admin/reports/${r.id}`, { status: 'dismissed' }).catch(() => {})
    }
    if (!old) await api(admin, 'DELETE', `/reviews/${review.id}`).catch(() => {})
    await adminContext.close()
  }
})
