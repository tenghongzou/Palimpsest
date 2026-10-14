<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">{{ $t('admin.menu.reports') }}</h1>

    <div class="flex items-center gap-3">
      <n-radio-group v-model:value="filters.status" @update:value="load(1)">
        <n-radio-button v-for="o in reportStatusOptions" :key="o.value" :value="o.value" :label="o.label" />
      </n-radio-group>
      <n-button @click="load()">{{ $t('admin.refresh') }}</n-button>
    </div>

    <n-data-table
      remote
      :columns="columns"
      :data="items"
      :loading="loading"
      :pagination="tablePagination"
      :row-key="(row: ApiReportView) => row.id"
      :scroll-x="1000"
    />

    <n-modal v-model:show="resolveOpen" preset="dialog" :title="$t('admin.reports.resolveTitle')" :show-icon="false">
      <div v-if="current" class="space-y-3">
        <div class="text-sm text-gray-500">
          {{ reportTargetLabel(current.target_type) }}{{ $t('admin.reports.colon') }}
          <span class="text-gray-800">{{ current.target_preview || $t('admin.reports.noPreview') }}</span>
        </div>
        <n-checkbox v-if="canHide(current)" v-model:checked="hideTarget">
          {{ $t('admin.reports.alsoHide', { target: reportTargetLabel(current.target_type) }) }}
        </n-checkbox>
      </div>
      <template #action>
        <n-button @click="resolveOpen = false">{{ $t('common.cancel') }}</n-button>
        <n-button :loading="saving" @click="close('dismissed')">{{ $t('admin.reports.dismiss') }}</n-button>
        <n-button type="primary" :loading="saving" @click="close('resolved')">{{ $t('admin.reports.markResolved') }}</n-button>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import {
  NButton, NCheckbox, NDataTable, NModal, NRadioButton, NRadioGroup, NTag, useMessage,
} from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { h } from 'vue'
import type { ApiReportView } from '~/types/models'
import { REPORT_REASONS } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })

const { t } = useI18n()
const { reportStatusOptions, reportStatusLabel, reportTargetLabel, dateTime } = useAdminLabels()
useHead({ title: () => t('admin.menu.reports') })

const message = useMessage()

const { items, loading, filters, tablePagination, load } = useAdminList<ApiReportView, {
  status: 'pending' | 'resolved' | 'dismissed'
}>('/admin/reports', { status: 'pending' })

const resolveOpen = ref(false)
const current = ref<ApiReportView | null>(null)
const hideTarget = ref(false)
const saving = ref(false)

function canHide(report: ApiReportView) {
  return report.target_type === 'review' || report.target_type === 'comment'
}

function openResolve(report: ApiReportView) {
  current.value = report
  hideTarget.value = canHide(report)
  resolveOpen.value = true
}

async function close(status: 'resolved' | 'dismissed') {
  if (!current.value) return
  saving.value = true
  try {
    await apiFetch(`/admin/reports/${current.value.id}`, {
      method: 'PUT',
      body: { status, hide_target: status === 'resolved' && hideTarget.value && canHide(current.value) },
    })
    message.success(reportStatusLabel(status))
    resolveOpen.value = false
    await load()
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('common.operationFailed')))
  }
  finally {
    saving.value = false
  }
}

const reasonLabel = (reason: string) =>
  (REPORT_REASONS as readonly string[]).includes(reason) ? t(`community.report.reasons.${reason}`) : reason

const columns = computed<DataTableColumns<ApiReportView>>(() => [
  { title: t('admin.reports.columns.type'), key: 'target_type', width: 80, render: row => reportTargetLabel(row.target_type) },
  {
    title: t('admin.reports.columns.target'),
    key: 'target_preview',
    minWidth: 240,
    render: row => h('div', { class: 'text-sm whitespace-pre-wrap' }, row.target_preview || t('admin.reports.deletedOrNoPreview')),
  },
  { title: t('community.report.reason'), key: 'reason', width: 100, render: row => reasonLabel(row.reason) },
  { title: t('admin.reports.columns.description'), key: 'description', minWidth: 160, render: row => row.description || '—' },
  { title: t('admin.reports.columns.reporter'), key: 'reporter', width: 120, render: row => row.reporter?.nickname || row.reporter?.username || row.reporter_id },
  {
    title: t('admin.columns.status'),
    key: 'status',
    width: 90,
    render: row => h(NTag, {
      size: 'small',
      type: row.status === 'pending' ? 'warning' : row.status === 'resolved' ? 'success' : 'default',
    }, () => reportStatusLabel(row.status)),
  },
  { title: t('admin.columns.time'), key: 'created_at', width: 170, render: row => dateTime(row.created_at) },
  {
    title: t('admin.columns.actions'),
    key: 'actions',
    width: 90,
    render: row => row.status === 'pending'
      ? h(NButton, { size: 'small', type: 'primary', onClick: () => openResolve(row) }, () => t('admin.reports.handle'))
      : dateTime(row.resolved_at),
  },
])

onMounted(() => load(1))
</script>
