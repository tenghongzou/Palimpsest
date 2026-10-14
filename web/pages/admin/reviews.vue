<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">{{ $t('admin.menu.reviews') }}</h1>

    <div class="flex items-center gap-3">
      <n-select
        v-model:value="filters.status"
        :options="moderationOptions"
        :placeholder="$t('category.allStatuses')"
        clearable
        class="w-36"
        @update:value="load(1)"
      />
      <n-button @click="load()">{{ $t('admin.refresh') }}</n-button>
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

const { t } = useI18n()
const { moderationOptions, moderationLabel, dateTime } = useAdminLabels()
useHead({ title: () => t('admin.menu.reviews') })

const message = useMessage()

const { items, loading, filters, tablePagination, load } = useAdminList<ApiReview, {
  status: ModerationStatus | null
}>('/admin/reviews', { status: null })

const statusTagType: Record<string, 'success' | 'error' | 'warning'> = {
  approved: 'success',
  rejected: 'error',
  hidden: 'warning',
}

async function moderate(review: ApiReview, status: ModerationStatus) {
  try {
    await apiFetch(`/admin/reviews/${review.id}`, { method: 'PUT', body: { status } })
    message.success(t('admin.reviews.setTo', { status: moderationLabel(status) }))
    await load()
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('common.operationFailed')))
  }
}

const columns = computed<DataTableColumns<ApiReview>>(() => [
  {
    title: t('admin.reports.targets.novel'),
    key: 'novel',
    width: 150,
    render: row => row.novel
      ? h(resolveComponent('NuxtLink'), { to: `/novel/${row.novel.id}`, class: 'text-primary', target: '_blank' }, () => row.novel?.title)
      : '—',
  },
  {
    title: t('admin.reports.targets.user'),
    key: 'user',
    width: 120,
    render: row => row.user?.nickname || row.user?.username || row.user_id,
  },
  {
    title: t('reviews.rating'),
    key: 'rating',
    width: 130,
    render: row => h(NRate, { value: row.rating, readonly: true, allowHalf: true, size: 'small' }),
  },
  {
    title: t('admin.columns.content'),
    key: 'content',
    minWidth: 260,
    render: row => h('div', [
      h('div', { class: 'font-semibold' }, row.title),
      h('div', { class: 'text-sm text-gray-600 whitespace-pre-wrap line-clamp-3' }, row.content),
    ]),
  },
  { title: t('community.like'), key: 'like_count', width: 60 },
  {
    title: t('admin.columns.status'),
    key: 'status',
    width: 90,
    render: row => h(NTag, { size: 'small', type: statusTagType[row.status] }, () => moderationLabel(row.status)),
  },
  { title: t('admin.columns.time'), key: 'created_at', width: 170, render: row => dateTime(row.created_at) },
  {
    title: t('admin.columns.actions'),
    key: 'actions',
    width: 210,
    render: row => h(NSpace, { size: 'small' }, () => (['approved', 'rejected', 'hidden'] as const)
      .filter(s => s !== row.status)
      .map(s => h(NButton, {
        size: 'small',
        type: s === 'approved' ? 'primary' : s === 'rejected' ? 'error' : 'warning',
        onClick: () => moderate(row, s),
      }, () => t(`admin.reviews.actions.${s}`)))),
  },
])

onMounted(() => load(1))
</script>
