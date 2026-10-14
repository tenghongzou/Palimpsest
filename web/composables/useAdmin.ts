// Helpers shared by the admin console pages.
import { useMessage } from 'naive-ui'
import { apiFetch, describeError, statusOf, type ApiResponse, type Paginated, type Pagination } from '~/utils/api'

export const NOVEL_STATUS_OPTIONS = [
  { label: '連載中', value: 'ongoing' },
  { label: '已完結', value: 'completed' },
  { label: '暫停', value: 'hiatus' },
]

export const LANGUAGE_OPTIONS = [
  { label: '繁體中文', value: 'zh-TW' },
  { label: '简体中文', value: 'zh-CN' },
  { label: 'English', value: 'en' },
]

export const MODERATION_LABELS: Record<string, string> = {
  approved: '已通過',
  rejected: '已拒絕',
  hidden: '已隱藏',
}

export const REPORT_STATUS_LABELS: Record<string, string> = {
  pending: '待處理',
  resolved: '已處理',
  dismissed: '已駁回',
}

export const REPORT_TARGET_LABELS: Record<string, string> = {
  review: '書評',
  comment: '留言',
  novel: '小說',
  chapter: '章節',
  user: '用戶',
}

export function labelOf(options: { label: string, value: string }[], value: string | undefined): string {
  return options.find(o => o.value === value)?.label ?? value ?? ''
}

/** Message for a failed image upload, with the storage/size/type cases spelled out. */
export function uploadErrorMessage(error: unknown): string {
  switch (statusOf(error)) {
    case 503: return '檔案儲存服務尚未設定，暫時無法上傳'
    case 413: return '檔案太大'
    case 415: return describeError(error, {}, '不支援的檔案格式，請上傳 JPEG、PNG、WebP 或 GIF')
    default: return describeError(error, {}, '上傳失敗')
  }
}

/** Formats an ISO timestamp for tables. */
export function adminDateTime(value: string | undefined | null): string {
  if (!value) return '—'
  const d = new Date(value)
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString('zh-TW', { hour12: false })
}

/**
 * A server-paginated list: keeps page/page_size/filters, loads on demand and
 * exposes props for n-data-table's remote pagination.
 */
export function useAdminList<T, F extends Record<string, unknown>>(path: string, initialFilters: F, pageSize = 20) {
  const items = ref<T[]>([]) as Ref<T[]>
  const loading = ref(false)
  const filters = reactive({ ...initialFilters }) as F
  const pagination = reactive<Pagination>({ page: 1, page_size: pageSize, total: 0, total_pages: 0 })
  const message = useMessage()

  async function load(page = pagination.page) {
    loading.value = true
    try {
      const params: Record<string, unknown> = { page, page_size: pagination.page_size }
      for (const [k, v] of Object.entries(filters)) {
        if (v !== null && v !== undefined && v !== '') params[k] = v
      }
      const res = await apiFetch<ApiResponse<Paginated<T>>>(path, { params })
      items.value = res.data.items
      Object.assign(pagination, res.data.pagination)
      pagination.page = res.data.pagination.page || page
    }
    catch (error) {
      message.error(describeError(error, {}, '載入失敗'))
    }
    finally {
      loading.value = false
    }
  }

  const tablePagination = computed(() => ({
    page: pagination.page,
    pageSize: pagination.page_size,
    itemCount: pagination.total,
    pageCount: Math.max(pagination.total_pages, 1),
    showSizePicker: true,
    pageSizes: [10, 20, 50, 100],
    onUpdatePage: (page: number) => load(page),
    onUpdatePageSize: (size: number) => {
      pagination.page_size = size
      void load(1)
    },
  }))

  return { items, loading, filters, pagination, tablePagination, load }
}
