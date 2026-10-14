<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">書評審核</h1>

    <div class="flex items-center gap-3">
      <n-select
        v-model:value="filters.status"
        :options="statusOptions"
        placeholder="全部狀態"
        clearable
        class="w-36"
        @update:value="load(1)"
      />
      <n-button @click="load()">重新整理</n-button>
    </div>

    <n-data-table
      remote
      :columns="columns"
      :data="items"
      :loading="loading"
      :pagination="tablePagination"
      :row-key="(row: ApiReview) => row.id"
      :scroll-x="1000"
    />
  </div>
</template>

<script setup lang="ts">
import { NButton, NDataTable, NRate, NSelect, NSpace, NTag, useMessage } from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { h } from 'vue'
import type { ApiReview, ModerationStatus } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })
useHead({ title: '書評審核 — Palimpsest' })

const message = useMessage()

const { items, loading, filters, tablePagination, load } = useAdminList<ApiReview, {
  status: ModerationStatus | null
}>('/admin/reviews', { status: null })

const statusOptions = Object.entries(MODERATION_LABELS).map(([value, label]) => ({ label, value }))

const statusTagType: Record<string, 'success' | 'error' | 'warning'> = {
  approved: 'success',
  rejected: 'error',
  hidden: 'warning',
}

async function moderate(review: ApiReview, status: ModerationStatus) {
  try {
    await apiFetch(`/admin/reviews/${review.id}`, { method: 'PUT', body: { status } })
    message.success(`已設為「${MODERATION_LABELS[status]}」`)
    await load()
  }
  catch (error) {
    message.error(describeError(error, {}, '操作失敗'))
  }
}

const columns: DataTableColumns<ApiReview> = [
  {
    title: '小說',
    key: 'novel',
    width: 150,
    render: row => row.novel
      ? h(resolveComponent('NuxtLink'), { to: `/novel/${row.novel.id}`, class: 'text-primary', target: '_blank' }, () => row.novel?.title)
      : '—',
  },
  {
    title: '用戶',
    key: 'user',
    width: 120,
    render: row => row.user?.nickname || row.user?.username || row.user_id,
  },
  {
    title: '評分',
    key: 'rating',
    width: 130,
    render: row => h(NRate, { value: row.rating, readonly: true, allowHalf: true, size: 'small' }),
  },
  {
    title: '內容',
    key: 'content',
    minWidth: 260,
    render: row => h('div', [
      h('div', { class: 'font-semibold' }, row.title),
      h('div', { class: 'text-sm text-gray-600 whitespace-pre-wrap line-clamp-3' }, row.content),
    ]),
  },
  { title: '讚', key: 'like_count', width: 60 },
  {
    title: '狀態',
    key: 'status',
    width: 90,
    render: row => h(NTag, { size: 'small', type: statusTagType[row.status] }, () => MODERATION_LABELS[row.status] ?? row.status),
  },
  { title: '時間', key: 'created_at', width: 170, render: row => adminDateTime(row.created_at) },
  {
    title: '操作',
    key: 'actions',
    width: 210,
    render: row => h(NSpace, { size: 'small' }, () => (['approved', 'rejected', 'hidden'] as const)
      .filter(s => s !== row.status)
      .map(s => h(NButton, {
        size: 'small',
        type: s === 'approved' ? 'primary' : s === 'rejected' ? 'error' : 'warning',
        onClick: () => moderate(row, s),
      }, () => ({ approved: '通過', rejected: '拒絕', hidden: '隱藏' })[s]))),
  },
]

onMounted(() => load(1))
</script>
