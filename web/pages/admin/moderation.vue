<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">{{ $t('admin.menu.moderation') }}</h1>

    <n-tabs :value="tab" type="line" @update:value="selectTab">
      <n-tab name="pending">
        <span class="inline-flex items-center gap-1.5">
          {{ $t('admin.moderationQueue.tabs.pending') }}
          <n-badge v-if="pending.count.value" :value="pending.count.value" :max="99" />
        </span>
      </n-tab>
      <n-tab name="flagged">{{ $t('admin.moderationQueue.tabs.flagged') }}</n-tab>
      <n-tab name="terms">{{ $t('admin.moderationQueue.tabs.terms') }}</n-tab>
    </n-tabs>

    <!-- Queues -->
    <template v-if="tab !== 'terms'">
      <div class="flex flex-wrap items-center gap-3">
        <n-radio-group v-model:value="typeFilter" size="small" data-testid="moderation-type">
          <n-radio-button value="all">{{ $t('admin.moderationQueue.allTypes') }}</n-radio-button>
          <n-radio-button v-for="type in MODERATION_TYPES" :key="type" :value="type">{{ $t(`admin.reports.targets.${type}`) }}</n-radio-button>
        </n-radio-group>
        <n-button size="small" :loading="loading" @click="load()">{{ $t('admin.refresh') }}</n-button>
        <span class="text-sm text-gray-500">{{ $t('admin.moderationQueue.total', { n: pagination.total }) }}</span>
      </div>
      <p class="text-xs text-gray-500">{{ $t(`admin.moderationQueue.help.${tab}`) }}</p>

      <div v-if="items.length" class="flex flex-wrap items-center gap-3 text-sm" data-testid="moderation-batch">
        <n-checkbox :checked="allSelected" :indeterminate="someSelected" :disabled="batchRunning" @update:checked="selectAll">
          {{ $t('admin.moderationQueue.selectPage') }}
        </n-checkbox>
        <template v-if="selected.size">
          <span class="text-gray-500">{{ $t('admin.moderationQueue.selected', { n: selected.size }) }}</span>
          <n-button size="small" type="primary" :loading="batchRunning" @click="batch('approved')">{{ $t('admin.moderationQueue.batchApprove') }}</n-button>
          <n-button size="small" type="error" secondary :disabled="batchRunning" @click="confirmBatchReject">{{ $t('admin.moderationQueue.batchReject') }}</n-button>
        </template>
      </div>

      <n-spin :show="loading">
        <div v-if="items.length" class="space-y-3" data-testid="moderation-list">
          <ModerationItemCard
            v-for="item in items"
            :key="itemKey(item)"
            :item="item"
            :selected="selected.has(itemKey(item))"
            :busy="busy[itemKey(item)] ?? null"
            @toggle="toggle(item, $event)"
            @decide="decide(item, $event)"
          />
        </div>
        <div v-else-if="failed" class="py-12">
          <n-empty :description="$t('common.loadFailed')">
            <template #extra><n-button size="small" @click="load()">{{ $t('common.retry') }}</n-button></template>
          </n-empty>
        </div>
        <n-empty v-else-if="!loading" class="py-12" :description="$t(`admin.moderationQueue.empty.${tab}`)" />
      </n-spin>

      <div v-if="pagination.total_pages > 1" class="flex justify-end">
        <n-pagination
          :page="pagination.page"
          :page-count="pagination.total_pages"
          :page-size="pagination.page_size"
          @update:page="load"
        />
      </div>
    </template>

    <!-- Terms -->
    <template v-else>
      <n-alert type="info" :show-icon="false" data-testid="terms-help">
        <div class="space-y-1 text-sm">
          <div><n-tag size="small" type="error">{{ $t('admin.moderationQueue.severities.block') }}</n-tag> {{ $t('admin.moderationQueue.severityHelp.block') }}</div>
          <div><n-tag size="small" type="warning">{{ $t('admin.moderationQueue.severities.flag') }}</n-tag> {{ $t('admin.moderationQueue.severityHelp.flag') }}</div>
          <div class="text-xs text-gray-500">{{ $t('admin.moderationQueue.severityHelp.matching') }}</div>
        </div>
      </n-alert>

      <form class="flex flex-wrap items-start gap-3" data-testid="term-form" @submit.prevent="addTerm">
        <n-form-item
          :show-label="false"
          :validation-status="termError ? 'error' : undefined"
          :feedback="termError ?? undefined"
          :show-feedback="!!termError"
          class="w-64"
        >
          <n-input v-model:value="newTerm" :placeholder="$t('admin.moderationQueue.termPlaceholder')" clearable show-count @input="termTouched = false" />
        </n-form-item>
        <n-select v-model:value="newSeverity" :options="severityOptions" class="w-32" />
        <n-button type="primary" attr-type="submit" :loading="addingTerm">{{ $t('admin.moderationQueue.addTerm') }}</n-button>
      </form>

      <n-data-table
        :columns="termColumns"
        :data="terms"
        :loading="termsLoading"
        :row-key="(row: ApiModerationTerm) => row.id"
        :pagination="{ pageSize: 50 }"
        :scroll-x="520"
        data-testid="terms-table"
      >
        <template #empty>
          <n-empty :description="$t('admin.moderationQueue.termsEmpty')" />
        </template>
      </n-data-table>
    </template>
  </div>
</template>

<script setup lang="ts">
import {
  NAlert, NBadge, NButton, NCheckbox, NDataTable, NEmpty, NFormItem, NInput, NPagination, NPopconfirm, NRadioButton,
  NRadioGroup, NSelect, NSpin, NTab, NTabs, NTag, useDialog, useMessage,
} from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { h } from 'vue'
import type { ApiResponse, Paginated, Pagination } from '~/utils/api'
import type { ApiModerationItem, ApiModerationTerm, ModerationSeverity } from '~/types/models'
import {
  MODERATION_SEVERITIES, MODERATION_TYPES, TERM_MAX_LENGTH, itemKey, pageAfterRemoval, validateTerm, withoutItems,
  type ModerationDecision, type ModerationItemType, type ModerationQueue,
} from '~/utils/moderation'
import ModerationItemCard from '~/components/admin/ModerationItemCard.vue'

definePageMeta({ middleware: 'admin', layout: 'admin' })

type Tab = ModerationQueue | 'terms'
const TABS: Tab[] = ['pending', 'flagged', 'terms']

const { t } = useI18n()
const { moderationLabel, dateTime } = useAdminLabels()
useHead({ title: () => t('admin.menu.moderation') })

const route = useRoute()
const router = useRouter()
const message = useMessage()
const dialog = useDialog()
const pending = usePendingModeration()

const tab = computed<Tab>(() => TABS.includes(route.query.tab as Tab) ? route.query.tab as Tab : 'pending')
function selectTab(value: Tab) {
  void router.replace({ query: { ...route.query, tab: value === 'pending' ? undefined : value } })
}

// ---- Queues
const typeFilter = ref<'all' | ModerationItemType>('all')
const items = ref<ApiModerationItem[]>([])
const pagination = reactive<Pagination>({ page: 1, page_size: 20, total: 0, total_pages: 0 })
const loading = ref(false)
const failed = ref(false)
const selected = ref(new Set<string>())
const busy = reactive<Record<string, ModerationDecision>>({})
const batchRunning = ref(false)
let request = 0

async function load(page = pagination.page) {
  if (tab.value === 'terms') return
  const id = ++request
  const queue = tab.value
  loading.value = true
  failed.value = false
  try {
    const res = await apiFetch<ApiResponse<Paginated<ApiModerationItem>>>('/admin/moderation/queue', {
      params: {
        queue,
        page,
        page_size: pagination.page_size,
        ...(typeFilter.value !== 'all' ? { type: typeFilter.value } : {}),
      },
    })
    if (id !== request) return
    items.value = res.data.items ?? []
    Object.assign(pagination, res.data.pagination)
    pagination.page = res.data.pagination.page || page
    selected.value = new Set()
    // The unfiltered pending queue's total is the badge count.
    if (queue === 'pending' && typeFilter.value === 'all') pending.set(pagination.total)
  }
  catch (error) {
    if (id !== request) return
    items.value = []
    failed.value = true
    message.error(describeError(t, error, {}, t('common.loadFailed')))
  }
  finally {
    if (id === request) loading.value = false
  }
}

const allSelected = computed(() => items.value.length > 0 && items.value.every(i => selected.value.has(itemKey(i))))
const someSelected = computed(() => selected.value.size > 0 && !allSelected.value)

function toggle(item: ApiModerationItem, checked: boolean) {
  const next = new Set(selected.value)
  if (checked) next.add(itemKey(item))
  else next.delete(itemKey(item))
  selected.value = next
}

function selectAll(checked: boolean) {
  selected.value = checked ? new Set(items.value.map(itemKey)) : new Set()
}

function put(item: ApiModerationItem, status: ModerationDecision) {
  return apiFetch(`/admin/moderation/${item.type}/${item.id}`, { method: 'PUT', body: { status } })
}

/** Drops decided items from the page; reloads when the page runs empty. */
function afterRemoval(removed: number) {
  pagination.total = Math.max(0, pagination.total - removed)
  if (tab.value === 'pending') pending.decrement(removed)
  if (!items.value.length && pagination.total > 0) void load(pageAfterRemoval(pagination.page, pagination.page_size, pagination.total))
}

/** Saves a decision, removing the item right away and restoring it if the request fails. */
async function decide(item: ApiModerationItem, status: ModerationDecision) {
  const key = itemKey(item)
  const index = items.value.findIndex(i => itemKey(i) === key)
  busy[key] = status
  items.value = withoutItems(items.value, [key])
  toggle(item, false)
  try {
    await put(item, status)
    message.success(t('admin.reviews.setTo', { status: moderationLabel(status) }))
    afterRemoval(1)
  }
  catch (error) {
    if (statusOf(error) === 404) {
      message.warning(t('admin.moderationQueue.gone'))
      afterRemoval(1)
    }
    else {
      const restored = [...items.value]
      restored.splice(Math.min(Math.max(index, 0), restored.length), 0, item)
      items.value = restored
      message.error(describeError(t, error, {}, t('common.operationFailed')))
    }
  }
  finally {
    delete busy[key]
  }
}

/** Applies a decision to the selected items one request at a time. */
async function batch(status: ModerationDecision) {
  const targets = items.value.filter(i => selected.value.has(itemKey(i)))
  if (!targets.length) return
  batchRunning.value = true
  let done = 0
  let failures = 0
  try {
    for (const item of targets) {
      const key = itemKey(item)
      busy[key] = status
      try {
        await put(item, status)
        done++
        items.value = withoutItems(items.value, [key])
        toggle(item, false)
      }
      catch (error) {
        if (statusOf(error) === 404) {
          done++
          items.value = withoutItems(items.value, [key])
          toggle(item, false)
        }
        else {
          failures++
        }
      }
      finally {
        delete busy[key]
      }
    }
  }
  finally {
    batchRunning.value = false
  }
  if (failures) message.warning(t('admin.moderationQueue.batchPartial', { ok: done, failed: failures }))
  else message.success(t('admin.moderationQueue.batchDone', { n: done }))
  afterRemoval(done)
}

function confirmBatchReject() {
  dialog.warning({
    title: t('admin.moderationQueue.batchReject'),
    content: t('admin.moderationQueue.confirmBatchReject', { n: selected.value.size }),
    positiveText: t('admin.reviews.actions.rejected'),
    negativeText: t('common.cancel'),
    onPositiveClick: () => { void batch('rejected') },
  })
}

// ---- Terms
const terms = ref<ApiModerationTerm[]>([])
const termsLoading = ref(false)
const newTerm = ref('')
const newSeverity = ref<ModerationSeverity>('block')
const addingTerm = ref(false)
const termTouched = ref(false)

const severityOptions = computed(() => MODERATION_SEVERITIES.map(value => ({ label: t(`admin.moderationQueue.severities.${value}`), value })))

const termError = computed(() => {
  if (!termTouched.value) return null
  const error = validateTerm(newTerm.value)
  if (error === 'required') return t('admin.moderationQueue.termRequired')
  if (error === 'tooLong') return t('admin.moderationQueue.termTooLong', { max: TERM_MAX_LENGTH })
  return null
})

async function loadTerms() {
  termsLoading.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiModerationTerm[]>>('/admin/moderation/terms')
    terms.value = res.data ?? []
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('common.loadFailed')))
  }
  finally {
    termsLoading.value = false
  }
}

async function addTerm() {
  termTouched.value = true
  if (validateTerm(newTerm.value)) return
  const term = newTerm.value.trim()
  addingTerm.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiModerationTerm>>('/admin/moderation/terms', {
      method: 'POST',
      body: { term, severity: newSeverity.value },
    })
    terms.value = [res.data, ...terms.value.filter(x => x.id !== res.data.id)]
    newTerm.value = ''
    termTouched.value = false
    message.success(t('admin.moderationQueue.termAdded', { term }))
  }
  catch (error) {
    if (statusOf(error) === 409) message.warning(t('admin.moderationQueue.termExists', { term }))
    else message.error(describeError(t, error, {}, t('common.saveFailed')))
  }
  finally {
    addingTerm.value = false
  }
}

async function removeTerm(term: ApiModerationTerm) {
  try {
    await apiFetch(`/admin/moderation/terms/${term.id}`, { method: 'DELETE' })
    message.success(t('admin.moderationQueue.termDeleted', { term: term.term }))
  }
  catch (error) {
    if (statusOf(error) !== 404) {
      message.error(describeError(t, error, {}, t('common.deleteFailed')))
      return
    }
  }
  terms.value = terms.value.filter(x => x.id !== term.id)
}

const termColumns = computed<DataTableColumns<ApiModerationTerm>>(() => [
  { title: t('admin.moderationQueue.term'), key: 'term', minWidth: 160, render: row => h('span', { class: 'font-medium' }, row.term) },
  {
    title: t('admin.moderationQueue.severity'),
    key: 'severity',
    width: 110,
    render: row => h(NTag, { size: 'small', type: row.severity === 'block' ? 'error' : 'warning' }, () => t(`admin.moderationQueue.severities.${row.severity}`)),
  },
  { title: t('admin.moderationQueue.createdAt'), key: 'created_at', width: 180, render: row => dateTime(row.created_at) },
  {
    title: t('admin.columns.actions'),
    key: 'actions',
    width: 90,
    render: row => h(NPopconfirm, { onPositiveClick: () => removeTerm(row) }, {
      trigger: () => h(NButton, { size: 'small', type: 'error', secondary: true }, () => t('common.delete')),
      default: () => t('admin.confirmDeleteNamed', { name: row.term }),
    }),
  },
])

// ---- Loading per tab
function loadTab() {
  if (tab.value === 'terms') void loadTerms()
  else {
    items.value = []
    void load(1)
  }
}

watch(tab, loadTab)
watch(typeFilter, () => load(1))
onMounted(loadTab)
</script>
