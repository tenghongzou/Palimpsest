import { expect, test, type Page } from '@playwright/test'
import { ADMIN_STATE, USER_STATE, api, chaptersOf, pickNovel, uniqueSuffix, POLL, ensureQuota } from './helpers'

test.use({ storageState: USER_STATE })

test.beforeEach(async ({ page }) => {
  await ensureQuota(page)
})

interface Comment { id: string, paragraph_index?: number }
interface Notification { id: string, type: string, comment_id?: string, chapter_id?: string, read_at: string | null }

async function unreadCount(page: Page): Promise<number> {
  return (await api<{ count: number }>(page, 'GET', '/notifications/unread-count')).count
}

/** Removes the reader's notifications so each test starts from an empty list. */
async function clearNotifications(page: Page) {
  const list = await api<{ items: Notification[] }>(page, 'GET', '/notifications?page_size=100')
  for (const n of list.items) await api(page, 'DELETE', `/notifications/${n.id}`)
}

test('comment replies notify the reader: bell badge, list, open the thread, read all and delete', async ({ page, browser }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)
  const text = `E2E 通知留言 ${uniqueSuffix()}`
  await clearNotifications(page)

  // The reader comments; the admin replies twice (each reply notifies the reader).
  const comment = await api<Comment>(page, 'POST', `/chapters/${first.id}/comments`, { content: text })
  const adminContext = await browser.newContext({ storageState: ADMIN_STATE })
  const admin = await adminContext.newPage()
  try {
    await api(admin, 'POST', `/chapters/${first.id}/comments`, { content: '管理員的回覆一', parent_id: comment.id })
    await expect.poll(() => unreadCount(page), POLL).toBeGreaterThanOrEqual(1)

    // The bell in the header shows the unread count.
    await page.goto('/')
    const bell = page.getByTestId('notification-bell')
    await expect(bell).toBeVisible()
    await expect(page.getByTestId('notification-badge')).toContainText(String(await unreadCount(page)))

    await bell.click()
    await expect(page).toHaveURL(/\/notifications$/)
    const item = page.getByTestId('notification-item').first()
    await expect(item).toHaveAttribute('data-unread', 'true')
    await expect(item).toContainText('留言回覆')

    // Opening it marks it read and shows the thread in the reader's comments.
    await item.click()
    await expect(page).toHaveURL(new RegExp(`/read/${first.id}\\?comment=${comment.id}`))
    const thread = page.locator(`[data-comment-id="${comment.id}"]`)
    await expect(thread).toBeVisible()
    await expect(thread).toContainText(text)
    await expect(thread).toContainText('管理員的回覆一')
    await expect.poll(() => unreadCount(page), POLL).toBe(0)

    // A second reply; the list shows unread styling, the filter and "read all".
    await api(admin, 'POST', `/chapters/${first.id}/comments`, { content: '管理員的回覆二', parent_id: comment.id })
    await expect.poll(() => unreadCount(page), POLL).toBe(1)
    await page.goto('/notifications')
    const list = page.getByTestId('notification-item')
    await expect(list.first()).toHaveAttribute('data-unread', 'true')
    await page.getByTestId('notification-filter').getByText('未讀').click()
    await expect(list).toHaveCount(1)
    await page.getByTestId('notification-read-all').click()
    await expect(page.getByText(/已將 1 則通知標為已讀/)).toBeVisible()
    await expect(list.first()).toHaveAttribute('data-unread', 'false')
    await expect(page.getByTestId('notification-badge')).not.toContainText('1')
    expect(await unreadCount(page)).toBe(0)

    // Delete every notification from the "all" list.
    const total = (await api<{ items: Notification[] }>(page, 'GET', '/notifications?page_size=100')).items.length
    expect(total).toBeGreaterThanOrEqual(2)
    await page.getByTestId('notification-filter').getByText('全部').click()
    await expect(list).toHaveCount(total)
    for (let i = 0; i < total; i++) {
      await list.first().getByTestId('notification-delete').click()
      await page.locator('.n-popconfirm').getByRole('button', { name: '確定' }).click()
      await expect(list).toHaveCount(total - i - 1)
      // Wait for the confirm popover to close before opening the next one.
      await expect(page.locator('.n-popconfirm')).toHaveCount(0)
    }
    await expect(page.getByTestId('notification-empty')).toBeVisible()
  }
  finally {
    await api(page, 'DELETE', `/comments/${comment.id}`).catch(() => {})
    await adminContext.close()
  }
})

test('a reply to a paragraph comment opens that paragraph\'s panel on the thread', async ({ page, browser }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)
  const text = `E2E 段落通知 ${uniqueSuffix()}`
  const comment = await api<Comment>(page, 'POST', `/chapters/${first.id}/comments`, { content: text, paragraph_index: 0 })
  const adminContext = await browser.newContext({ storageState: ADMIN_STATE })
  const admin = await adminContext.newPage()
  try {
    const reply = await api<Comment>(admin, 'POST', `/chapters/${first.id}/comments`, { content: '段落裡的回覆', parent_id: comment.id })
    // The notification names the top-level comment; a reply id resolves to the same thread.
    await expect.poll(async () => (await api<{ items: Notification[] }>(page, 'GET', '/notifications?page_size=20')).items
      .some(n => n.type === 'comment_reply' && n.comment_id === comment.id), POLL).toBe(true)

    await page.goto(`/read/${first.id}?comment=${reply.id}`)
    const drawer = page.getByTestId('paragraph-comments-drawer')
    await expect(drawer).toBeVisible()
    await expect(page.getByText('第 1 段的評論')).toBeVisible()
    const thread = drawer.locator(`[data-comment-id="${comment.id}"]`)
    await expect(thread).toContainText(text)
    await expect(thread).toContainText('段落裡的回覆')
  }
  finally {
    await api(page, 'DELETE', `/comments/${comment.id}`).catch(() => {})
    await clearNotifications(page).catch(() => {})
    await adminContext.close()
  }
})

test('system announcements show their full text and only get marked read', async ({ page }) => {
  await clearNotifications(page)
  const title = `E2E 公告 ${uniqueSuffix()}`
  const body = '第一行內容\n第二行內容'
  // A notification list served by a stub, so no announcement goes out to every user.
  await page.route(/\/api\/v1\/notifications\?/, route => route.fulfill({
    json: {
      code: 0,
      message: 'success',
      data: {
        items: [{ id: '00000000-0000-4000-8000-000000000001', type: 'system', title, body, read_at: null, created_at: new Date().toISOString() }],
        pagination: { page: 1, page_size: 20, total: 1, total_pages: 1 },
      },
    },
  }))
  await page.route(/\/api\/v1\/notifications\/[^/]+\/read$/, route => route.fulfill({ json: { code: 0, message: 'success' } }))

  await page.goto('/notifications')
  const item = page.getByTestId('notification-item')
  await expect(item).toContainText('系統公告')
  await expect(item.getByTestId('notification-body')).toHaveText(body)
  await item.click()
  await expect(item).toHaveAttribute('data-unread', 'false')
  await expect(page).toHaveURL(/\/notifications$/)
})

test('notifications page shows an empty state', async ({ page }) => {
  await clearNotifications(page)
  await page.goto('/notifications')
  await expect(page.getByTestId('notification-empty')).toContainText('目前沒有通知')
  await page.getByTestId('notification-filter').getByText('未讀').click()
  await expect(page.getByTestId('notification-empty')).toContainText('沒有未讀通知')
  await expect(page.getByTestId('notification-read-all')).toBeDisabled()
})

test('paragraph comments: comment on a paragraph, see its marker, reply and delete', async ({ page, context }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)
  const text = `E2E 段落評論 ${uniqueSuffix()}`

  await page.goto(`/read/${first.id}`)
  const paragraphs = page.getByTestId('reader-paragraphs').locator('p')
  await expect(paragraphs.first()).toBeVisible()
  const index = (await paragraphs.count()) > 1 ? 1 : 0
  const target = page.locator(`[data-p="${index}"]`)
  const paragraphText = (await target.evaluate(el => el.firstChild?.textContent ?? '')).trim()
  const before = (await api<{ paragraph_index: number, count: number }[]>(page, 'GET', `/chapters/${first.id}/comments/paragraph-counts`))
    .find(c => c.paragraph_index === index)?.count ?? 0

  // Hovering a paragraph reveals its comment button (or its count marker).
  await target.hover()
  const opener = target.getByTestId(before ? 'paragraph-comment-count' : 'paragraph-comment-add')
  await opener.click()
  const drawer = page.getByTestId('paragraph-comments-drawer')
  await expect(drawer).toBeVisible()
  await expect(page.getByText(`第 ${index + 1} 段的評論`)).toBeVisible()
  await expect(drawer.getByTestId('paragraph-excerpt')).toContainText(paragraphText.slice(0, 10))

  const panel = drawer.getByTestId('paragraph-comments')
  await panel.getByTestId('comment-input').locator('textarea').fill(text)
  await panel.getByTestId('comment-submit').click()
  const item = panel.getByTestId('comment-item').filter({ hasText: text })
  await expect(item).toBeVisible()

  // The marker on the paragraph shows the new count; the server agrees.
  await expect(target.getByTestId('paragraph-comment-count')).toHaveText(String(before + 1))
  const comments = await api<{ items: (Comment & { content: string })[] }>(page, 'GET', `/chapters/${first.id}/comments?paragraph_index=${index}&page_size=100`)
  const created = comments.items.find(c => c.content === text)
  expect(created?.paragraph_index).toBe(index)

  // Replies stay in the thread and do not change the paragraph count.
  await item.getByRole('button', { name: '回覆' }).first().click()
  await panel.getByTestId('comment-input').locator('textarea').fill('段落回覆')
  await panel.getByTestId('comment-submit').click()
  await expect(item.getByTestId('comment-content').filter({ hasText: '段落回覆' })).toBeVisible()
  await expect(target.getByTestId('paragraph-comment-count')).toHaveText(String(before + 1))

  // The whole-chapter comments still list it, tagged with the paragraph.
  await page.keyboard.press('Escape')
  await expect(drawer).toBeHidden()
  await page.getByTestId('reader-comments').click()
  const chapterItem = page.getByTestId('chapter-comments').getByTestId('comment-item').filter({ hasText: text })
  await expect(chapterItem).toContainText(`第 ${index + 1} 段`)
  await page.keyboard.press('Escape')

  // Offline: markers are hidden.
  await context.setOffline(true)
  await expect(page.getByTestId('paragraph-comment-count')).toHaveCount(0)
  await context.setOffline(false)
  await expect(target.getByTestId('paragraph-comment-count')).toHaveText(String(before + 1))

  // Delete it from the paragraph drawer; the marker goes back.
  await target.getByTestId('paragraph-comment-count').click()
  await expect(item).toBeVisible()
  await item.getByRole('button', { name: '刪除' }).first().click()
  await page.locator('.n-popconfirm').getByRole('button', { name: '確定' }).click()
  await expect(item).toHaveCount(0)
  if (before) await expect(target.getByTestId('paragraph-comment-count')).toHaveText(String(before))
  else await expect(target.getByTestId('paragraph-comment-count')).toHaveCount(0)
  await expect.poll(async () => (await api<{ paragraph_index: number, count: number }[]>(page, 'GET', `/chapters/${first.id}/comments/paragraph-counts`))
    .find(c => c.paragraph_index === index)?.count ?? 0, POLL).toBe(before)
})

test('the paragraph comment button is keyboard accessible', async ({ page }) => {
  const novel = await pickNovel(page, 1)
  const [first] = await chaptersOf(page, novel.id)
  await page.goto(`/read/${first.id}`)
  const firstParagraph = page.locator('[data-p="0"]')
  await expect(firstParagraph).toBeVisible()
  const button = firstParagraph.locator('[data-testid^="paragraph-comment-"]')
  await button.focus()
  await page.keyboard.press('Enter')
  await expect(page.getByTestId('paragraph-comments-drawer')).toBeVisible()
  await expect(page.getByText('第 1 段的評論')).toBeVisible()
})
