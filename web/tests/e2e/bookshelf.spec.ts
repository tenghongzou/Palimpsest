import { expect, test } from '@playwright/test'
import { USER_STATE, api, POLL, ensureQuota } from './helpers'

test.use({ storageState: USER_STATE })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

interface ShelfEntry { novel_id: string, group_name: string }

test('add novels, group them, filter by group and remove several at once', async ({ page }) => {
  const res = await page.request.get('/api/v1/novels', { params: { page_size: 10 } })
  const novels = (await res.json() as { data: { items: { id: string, title: string }[] } }).data.items.slice(0, 2)
  test.skip(novels.length < 2, 'needs two published novels')

  // Start from an empty shelf.
  const shelf = await api<ShelfEntry[]>(page, 'GET', '/bookshelf')
  if (shelf.length) await api(page, 'POST', '/bookshelf/batch-remove', { novel_ids: shelf.map(s => s.novel_id) })

  // Add both from their detail pages.
  for (const n of novels) {
    await page.goto(`/novel/${n.id}`)
    await page.getByTestId('add-bookshelf').click()
    await expect(page.getByTestId('add-bookshelf')).toHaveText('已在書架')
  }

  await page.goto('/bookshelf')
  await expect(page.getByTestId('bookshelf-item')).toHaveCount(2)
  await expect(page.getByTestId('bookshelf-item').first()).toContainText('預設')

  // Move the first novel into a new group.
  const first = page.getByTestId('bookshelf-item').filter({ hasText: novels[0].title })
  await first.getByTestId('bookshelf-move').click()
  const select = page.getByTestId('bookshelf-group-select')
  await select.click()
  await page.keyboard.type('追更')
  await page.keyboard.press('Enter')
  await page.getByTestId('bookshelf-move-confirm').click()
  await expect(first).toContainText('追更')
  await expect.poll(async () => (await api<ShelfEntry[]>(page, 'GET', '/bookshelf')).find(s => s.novel_id === novels[0].id)?.group_name, POLL)
    .toBe('追更')

  // Filter by group.
  await page.locator('.n-tabs-tab', { hasText: '追更' }).click()
  await expect(page.getByTestId('bookshelf-item')).toHaveCount(1)
  await page.locator('.n-tabs-tab', { hasText: '全部' }).click()
  await expect(page.getByTestId('bookshelf-item')).toHaveCount(2)

  // Multi-select removal.
  await page.getByTestId('bookshelf-manage').click()
  await page.getByTestId('bookshelf-batch-bar').getByText('全選').click()
  await expect(page.getByTestId('bookshelf-batch-bar')).toContainText('已選 2 本')
  await page.getByTestId('bookshelf-remove-selected').click()
  await page.locator('.n-popconfirm').getByRole('button', { name: '確定' }).click()
  await expect(page.getByTestId('bookshelf-item')).toHaveCount(0)
  expect(await api<ShelfEntry[]>(page, 'GET', '/bookshelf')).toHaveLength(0)
})

test('shelf entries show reading progress', async ({ page }) => {
  const res = await page.request.get('/api/v1/novels', { params: { page_size: 10 } })
  const novel = (await res.json() as { data: { items: { id: string, title: string }[] } }).data.items[0]
  const chapters = (await (await page.request.get(`/api/v1/novels/${novel.id}/chapters`)).json() as { data: { id: string, title: string }[] }).data

  await api(page, 'POST', '/bookshelf', { novel_id: novel.id }).catch(() => {}) // may already be shelved
  await api(page, 'PUT', `/reading-progress/${novel.id}`, { chapter_id: chapters[0].id, paragraph_index: 0, scroll_offset: 0.5 })

  await page.goto('/bookshelf')
  const item = page.getByTestId('bookshelf-item').filter({ hasText: novel.title })
  await expect(item.getByTestId('bookshelf-progress')).toContainText(chapters[0].title)

  // Clicking the entry continues reading.
  await item.getByTestId('bookshelf-title').click()
  await expect(page).toHaveURL(new RegExp(`/read/${chapters[0].id}`))

  await api(page, 'DELETE', `/bookshelf/${novel.id}`)
})
