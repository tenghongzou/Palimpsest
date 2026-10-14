import { expect, test, type Page } from '@playwright/test'
import { ADMIN_STATE, api, uniqueSuffix, ensureQuota } from './helpers'

test.use({ storageState: ADMIN_STATE })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

async function confirmDialog(page: Page, button: string) {
  await page.locator('.n-dialog').getByRole('button', { name: button, exact: true }).click()
}

test('dashboard shows site statistics', async ({ page }) => {
  await page.goto('/admin')
  const stats = page.getByTestId('admin-stats')
  await expect(stats).toBeVisible()
  await expect(stats.getByText('用戶總數')).toBeVisible()
  await expect(stats.getByText('待處理檢舉')).toBeVisible()
})

test('create a category, a novel with chapters, publish it and clean up', async ({ page }) => {
  const suffix = uniqueSuffix()
  const categoryName = `E2E分類${suffix}`
  const slug = `e2e-${suffix}`
  const title = `E2E小說${suffix}`
  let novelId: string | undefined

  try {
    // Category
    await page.goto('/admin/categories')
    await page.getByRole('button', { name: '新增分類' }).click()
    await page.getByPlaceholder('分類名稱').fill(categoryName)
    await page.getByPlaceholder('英文代稱，例如 xuanhuan').fill(slug)
    await page.getByRole('button', { name: '儲存分類' }).click()
    await expect(page.getByRole('cell', { name: slug, exact: true })).toBeVisible()

    // Novel
    await page.goto('/admin/novels/new')
    await page.getByPlaceholder('書名', { exact: true }).fill(title)
    await page.getByPlaceholder('作者名稱').fill('E2E 作者')
    await page.getByPlaceholder('小說簡介').fill('端對端測試建立的小說')
    await page.getByTestId('novel-categories').click()
    await page.locator('.n-base-select-option', { hasText: categoryName }).click()
    await page.keyboard.press('Escape')
    await page.getByRole('button', { name: '儲存', exact: true }).click()
    await page.waitForURL(/\/admin\/novels\/[0-9a-f-]{36}$/)
    novelId = page.url().split('/').pop()

    // One chapter by hand
    await page.getByRole('button', { name: '管理章節' }).click()
    await page.waitForURL(/\/chapters$/)
    await page.getByRole('button', { name: '新增章節' }).click()
    await page.getByPlaceholder('章節標題').fill('第一章 起點')
    await page.getByPlaceholder('章節內容，段落之間以換行分隔').fill('第一段。\n\n第二段。')
    await page.getByRole('button', { name: '儲存章節' }).click()
    await expect(page.getByRole('cell', { name: '第一章 起點' })).toBeVisible()

    // Two more by batch import
    await page.getByRole('button', { name: '批次匯入' }).click()
    await page.getByPlaceholder('在此貼上章節內容').fill('第二章 中途\n內容二。\n\n第三章 終點\n內容三。')
    await expect(page.getByText('預覽：共 2 章')).toBeVisible()
    await page.getByRole('button', { name: '匯入 2 章' }).click()
    await expect(page.getByText('已匯入 2 章')).toBeVisible()
    // The preview table in the closing modal also has this cell; check the page's own table.
    await expect(page.locator('#__nuxt').getByRole('cell', { name: '第三章 終點' })).toBeVisible()

    // Publish from the edit page
    await page.getByRole('button', { name: '← 返回小說' }).click()
    await page.waitForURL(/\/admin\/novels\/[0-9a-f-]{36}$/)
    await page.getByRole('button', { name: '上架', exact: true }).click()
    await expect(page.getByText('已上架', { exact: true }).first()).toBeVisible()

    // Listed and searchable
    await page.goto('/admin/novels')
    await page.getByPlaceholder('搜尋書名或作者').fill(title)
    await page.getByPlaceholder('搜尋書名或作者').press('Enter')
    const row = page.locator('tr', { hasText: title })
    await expect(row).toHaveCount(1)
    await expect(row.getByText('已上架')).toBeVisible()

    // Delete through the UI
    await row.getByRole('button', { name: '刪除' }).click()
    await confirmDialog(page, '刪除')
    await expect(page.locator('tr', { hasText: title })).toHaveCount(0)
    novelId = undefined

    await page.goto('/admin/categories')
    await page.locator('tr', { hasText: slug }).getByRole('button', { name: '刪除' }).click()
    await confirmDialog(page, '刪除')
    await expect(page.getByRole('cell', { name: slug, exact: true })).toHaveCount(0)
  }
  finally {
    // Leave no test data behind if a step failed.
    if (novelId) await api(page, 'DELETE', `/admin/novels/${novelId}`).catch(() => {})
    const cats = await api<{ id: number, slug: string }[]>(page, 'GET', '/admin/categories').catch(() => [])
    const cat = cats.find(c => c.slug === slug)
    if (cat) await api(page, 'DELETE', `/admin/categories/${cat.id}`).catch(() => {})
  }
})

test('users can be listed and filtered', async ({ page }) => {
  await page.goto('/admin/users')
  await expect(page.locator('.n-data-table-tbody tr').first()).toBeVisible()
  await page.getByPlaceholder('搜尋帳號、電子郵件或暱稱').fill('admin')
  await page.getByPlaceholder('搜尋帳號、電子郵件或暱稱').press('Enter')
  await expect(page.getByText('@admin', { exact: true })).toBeVisible()
  await expect(page.getByText('目前帳號')).toBeVisible()
})

test('moderation pages load', async ({ page }) => {
  await page.goto('/admin/reviews')
  await expect(page.getByRole('heading', { name: '書評審核' })).toBeVisible()
  await expect(page.locator('.n-data-table')).toBeVisible()

  await page.goto('/admin/reports')
  await expect(page.getByRole('heading', { name: '檢舉處理' })).toBeVisible()
  await expect(page.getByText('待處理', { exact: true }).first()).toBeVisible()

  await page.goto('/admin/banners')
  await expect(page.getByRole('heading', { name: '橫幅管理' })).toBeVisible()
})

test('send a system announcement after confirming', async ({ page }) => {
  // The request is stubbed so the run does not notify every user.
  let sent: unknown = null
  await page.route(/\/api\/v1\/admin\/notifications\/broadcast$/, async (route) => {
    sent = route.request().postDataJSON()
    await route.fulfill({ status: 201, json: { code: 0, message: 'success', data: { recipients: 42 } } })
  })
  const title = `E2E 公告 ${uniqueSuffix()}`

  await page.goto('/admin/notifications')
  await expect(page.getByRole('heading', { name: '系統公告', exact: true })).toBeVisible()
  await expect(page.getByTestId('broadcast-submit')).toBeDisabled()
  await page.getByTestId('broadcast-title').locator('input').fill(title)
  await page.getByTestId('broadcast-body').locator('textarea').fill('維護時間：凌晨 2 點至 4 點')

  // Cancelling sends nothing.
  await page.getByTestId('broadcast-submit').click()
  await confirmDialog(page, '取消')
  expect(sent).toBeNull()

  await page.getByTestId('broadcast-submit').click()
  await expect(page.locator('.n-dialog')).toContainText(title)
  await confirmDialog(page, '發送')
  await expect(page.getByTestId('broadcast-result')).toContainText('42 位用戶')
  expect(sent).toEqual({ title, body: '維護時間：凌晨 2 點至 4 點' })
  await expect(page.getByTestId('broadcast-title').locator('input')).toHaveValue('')
})
