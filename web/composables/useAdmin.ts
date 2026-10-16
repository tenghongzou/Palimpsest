// Helpers shared by the admin console pages.
import { useMessage } from 'naive-ui'
import { apiFetch, describeError, statusOf, type ApiResponse, type Paginated, type Pagination } from '~/utils/api'
import { LOCALE_NAMES, intlLocale } from '~/i18n/constants'
import type { ApiAdminStats } from '~/types/models'

export const NOVEL_STATUSES = ['ongoing', 'completed', 'hiatus'] as const

/** A novel's content language (not the UI language); each shown in its own script. */
export const LANGUAGE_OPTIONS = (['zh-TW', 'zh-CN', 'en'] as const).map(value => ({ label: LOCALE_NAMES[value], value }))

export const MODERATION_STATUSES = ['pending', 'approved', 'rejected', 'hidden'] as const
export const REPORT_STATUSES = ['pending', 'resolved', 'dismissed'] as const
export const REPORT_TARGETS = ['review', 'comment', 'novel', 'chapter', 'user'] as const

/** The translation of `${prefix}.${value}` for known values, else the raw value. */
function keyedLabel(t: (key: string) => string, prefix: string, known: readonly string[], value: string | undefined): string {
  if (!value) return ''
  return known.includes(value) ? t(`${prefix}.${value}`) : value
}

/** Labels and options for admin enums in the UI language. */
export function useAdminLabels() {
  const { t, locale } = useI18n()
  const options = (prefix: string, values: readonly string[]) => computed(() => values.map(value => ({ label: t(`${prefix}.${value}`), value })))
  return {
    novelStatusOptions: options('novel.status', NOVEL_STATUSES),
    moderationOptions: options('admin.moderation', MODERATION_STATUSES),
    reportStatusOptions: options('admin.reports.status', REPORT_STATUSES),
    novelStatusLabel: (v?: string) => keyedLabel(t, 'novel.status', NOVEL_STATUSES, v),
    moderationLabel: (v?: string) => keyedLabel(t, 'admin.moderation', MODERATION_STATUSES, v),
    reportStatusLabel: (v?: string) => keyedLabel(t, 'admin.reports.status', REPORT_STATUSES, v),
    reportTargetLabel: (v?: string) => keyedLabel(t, 'admin.reports.targets', REPORT_TARGETS, v),
    dateTime: (v: string | undefined | null) => adminDateTime(v, locale.value),
  }
}

/** Naive UI tag type for a moderation status. */
export function moderationTagType(status: string | undefined): 'default' | 'info' | 'success' | 'error' | 'warning' {
  switch (status) {
    case 'pending': return 'info'
    case 'approved': return 'success'
    case 'rejected': return 'error'
    case 'hidden': return 'warning'
    default: return 'default'
  }
}

/**
 * How many reviews and comments await moderation, shared by the admin menu
 * badge, the dashboard and the moderation page. `refresh` reads it from
 * /admin/stats; pages that already have the number call `set`.
 */
export function usePendingModeration() {
  const count = useState<number | null>('admin.pendingModeration', () => null)

  async function refresh() {
    try {
      const res = await apiFetch<ApiResponse<ApiAdminStats>>('/admin/stats', { params: { utc_offset: -new Date().getTimezoneOffset() } })
      count.value = res.data.pending_moderation ?? 0
    }
    catch {
      // The badge is optional; keep the last known count.
    }
  }

  function set(value: number | null | undefined) {
    if (typeof value === 'number' && Number.isFinite(value)) count.value = Math.max(0, value)
  }

  function decrement(by = 1) {
    if (count.value !== null) count.value = Math.max(0, count.value - by)
  }

  return { count, refresh, set, decrement }
}

/**
 * One independently loaded dashboard section: keeps its data, loading and
 * failure state, and ignores responses superseded by a newer request.
 */
export function useAdminSection<T>(fetcher: () => Promise<T>) {
  const data = ref<T | null>(null) as Ref<T | null>
  const loading = ref(false)
  const failed = ref(false)
  let current = 0

  async function run() {
    const id = ++current
    loading.value = true
    failed.value = false
    try {
      const result = await fetcher()
      if (id === current) data.value = result
    }
    catch {
      if (id === current) {
        data.value = null
        failed.value = true
      }
    }
    finally {
      if (id === current) loading.value = false
    }
  }

  return { data, loading, failed, run }
}

/** Message for a failed image upload, with the storage/size/type cases spelled out. */
export function uploadErrorMessage(t: (key: string) => string, error: unknown): string {
  switch (statusOf(error)) {
    case 503: return t('admin.image.storageUnavailable')
    case 413: return t('admin.image.fileTooLarge')
    case 415: return describeError(t, error, {}, t('admin.image.unsupportedType'))
    default: return describeError(t, error, {}, t('admin.image.uploadFailed'))
  }
}

/** Formats an ISO timestamp for tables. */
export function adminDateTime(value: string | undefined | null, locale = 'zh-TW'): string {
  if (!value) return '—'
  const d = new Date(value)
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString(intlLocale(locale), { hour12: false })
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
  const { t } = useI18n()

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
      message.error(describeError(t, error, {}, t('common.loadFailed')))
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
