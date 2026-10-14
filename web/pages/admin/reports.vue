<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">檢舉處理</h1>

    <div class="flex items-center gap-3">
      <n-radio-group v-model:value="filters.status" @update:value="load(1)">
        <n-radio-button v-for="o in statusOptions" :key="o.value" :value="o.value" :label="o.label" />
      </n-radio-group>
      <n-button @click="load()">重新整理</n-button>
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

    <n-modal v-model:show="resolveOpen" preset="dialog" title="處理檢舉" :show-icon="false">
      <div v-if="current" class="space-y-3">
        <div class="text-sm text-gray-500">
          {{ REPORT_TARGET_LABELS[current.target_type] ?? current.target_type }}：
          <span class="text-gray-800">{{ current.target_preview || '（無預覽）' }}</span>
        </div>
        <n-checkbox v-if="canHide(current)" v-model:checked="hideTarget">
          同時隱藏被檢舉的{{ REPORT_TARGET_LABELS[current.target_type] }}
        </n-checkbox>
      </div>
      <template #action>
        <n-button @click="resolveOpen = false">取消</n-button>
        <n-button :loading="saving" @click="close('dismissed')">駁回</n-button>
        <n-button type="primary" :loading="saving" @click="close('resolved')">標記為已處理</n-button>
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
useHead({ title: '檢舉處理 — Palimpsest' })

const message = useMessage()

const { items, loading, filters, tablePagination, load } = useAdminList<ApiReportView, {
  status: 'pending' | 'resolved' | 'dismissed'
}>('/admin/reports', { status: 'pending' })

const statusOptions = Object.entries(REPORT_STATUS_LABELS).map(([value, label]) => ({ label, value }))

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
    message.success(status === 'resolved' ? '已處理' : '已駁回')
    resolveOpen.value = false
    await load()
  }
  catch (error) {
    message.error(describeError(error, {}, '操作失敗'))
  }
  finally {
    saving.value = false
  }
}

const reasonLabel = (reason: string) => REPORT_REASONS.find(r => r.value === reason)?.label ?? reason

const columns: DataTableColumns<ApiReportView> = [
  { title: '類型', key: 'target_type', width: 80, render: row => REPORT_TARGET_LABELS[row.target_type] ?? row.target_type },
  {
    title: '被檢舉內容',
    key: 'target_preview',
    minWidth: 240,
    render: row => h('div', { class: 'text-sm whitespace-pre-wrap' }, row.target_preview || '（內容已刪除或無預覽）'),
  },
  { title: '原因', key: 'reason', width: 100, render: row => reasonLabel(row.reason) },
  { title: '說明', key: 'description', minWidth: 160, render: row => row.description || '—' },
  { title: '檢舉人', key: 'reporter', width: 120, render: row => row.reporter?.nickname || row.reporter?.username || row.reporter_id },
  {
    title: '狀態',
    key: 'status',
    width: 90,
    render: row => h(NTag, {
      size: 'small',
      type: row.status === 'pending' ? 'warning' : row.status === 'resolved' ? 'success' : 'default',
    }, () => REPORT_STATUS_LABELS[row.status] ?? row.status),
  },
  { title: '時間', key: 'created_at', width: 170, render: row => adminDateTime(row.created_at) },
  {
    title: '操作',
    key: 'actions',
    width: 90,
    render: row => row.status === 'pending'
      ? h(NButton, { size: 'small', type: 'primary', onClick: () => openResolve(row) }, () => '處理')
      : adminDateTime(row.resolved_at),
  },
]

onMounted(() => load(1))
</script>
