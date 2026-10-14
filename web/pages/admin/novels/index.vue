<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">小說管理</h1>
      <n-button type="primary" @click="router.push('/admin/novels/new')">新增小說</n-button>
    </div>

    <div class="flex flex-wrap items-center gap-3">
      <n-input
        v-model:value="filters.q"
        placeholder="搜尋書名或作者"
        clearable
        class="max-w-64"
        @keyup.enter="load(1)"
        @clear="clearSearch"
      />
      <n-select
        v-model:value="filters.status"
        :options="NOVEL_STATUS_OPTIONS"
        placeholder="全部狀態"
        clearable
        class="w-32"
        @update:value="load(1)"
      />
      <n-select
        v-model:value="filters.is_published"
        :options="publishedOptions"
        placeholder="上架狀態"
        clearable
        class="w-32"
        @update:value="load(1)"
      />
      <n-button @click="load(1)">搜尋</n-button>
    </div>

    <n-data-table
      remote
      :columns="columns"
      :data="items"
      :loading="loading"
      :pagination="tablePagination"
      :row-key="(row: ApiNovel) => row.id"
      :scroll-x="1000"
    />
  </div>
</template>

<script setup lang="ts">
import {
  NButton, NDataTable, NInput, NSelect, NSpace, NTag, useDialog, useMessage,
} from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { h } from 'vue'
import type { ApiResponse } from '~/utils/api'
import type { ApiNovel } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })
useHead({ title: '小說管理 — Palimpsest' })

const router = useRouter()
const message = useMessage()
const dialog = useDialog()

const { items, loading, filters, tablePagination, load } = useAdminList<ApiNovel, {
  q: string
  status: string | null
  is_published: string | null
}>('/admin/novels', { q: '', status: null, is_published: null })

const publishedOptions = [
  { label: '已上架', value: 'true' },
  { label: '未上架', value: 'false' },
]

function clearSearch() {
  filters.q = ''
  void load(1)
}

async function togglePublish(novel: ApiNovel) {
  const publish = !novel.is_published
  try {
    await apiFetch<ApiResponse<ApiNovel>>(`/admin/novels/${novel.id}/publish`, {
      method: 'POST',
      body: { is_published: publish },
    })
    message.success(publish ? '已上架' : '已下架')
    await load()
  }
  catch (error) {
    message.error(describeError(error, {}, '操作失敗'))
  }
}

function confirmDelete(novel: ApiNovel) {
  dialog.warning({
    title: '刪除小說',
    content: `確定要刪除「${novel.title}」嗎？此操作會一併隱藏其章節。`,
    positiveText: '刪除',
    negativeText: '取消',
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/novels/${novel.id}`, { method: 'DELETE' })
        message.success('已刪除')
        await load()
      }
      catch (error) {
        message.error(describeError(error, {}, '刪除失敗'))
      }
    },
  })
}

const columns: DataTableColumns<ApiNovel> = [
  {
    title: '書名',
    key: 'title',
    minWidth: 180,
    render: row => h('a', {
      class: 'text-primary cursor-pointer',
      onClick: () => router.push(`/admin/novels/${row.id}`),
    }, row.title),
  },
  { title: '作者', key: 'author_name', width: 120 },
  {
    title: '狀態',
    key: 'status',
    width: 90,
    render: row => labelOf(NOVEL_STATUS_OPTIONS, row.status),
  },
  {
    title: '上架',
    key: 'is_published',
    width: 90,
    render: row => h(NTag, { size: 'small', type: row.is_published ? 'success' : 'default' }, () => row.is_published ? '已上架' : '未上架'),
  },
  {
    title: '推薦',
    key: 'is_featured',
    width: 70,
    render: row => row.is_featured ? '是' : '',
  },
  { title: '章節', key: 'total_chapters', width: 70 },
  { title: '更新時間', key: 'updated_at', width: 170, render: row => adminDateTime(row.updated_at) },
  {
    title: '操作',
    key: 'actions',
    width: 260,
    render: row => h(NSpace, { size: 'small' }, () => [
      h(NButton, { size: 'small', onClick: () => router.push(`/admin/novels/${row.id}`) }, () => '編輯'),
      h(NButton, { size: 'small', onClick: () => router.push(`/admin/novels/${row.id}/chapters`) }, () => '章節'),
      h(NButton, {
        size: 'small',
        type: row.is_published ? 'warning' : 'primary',
        onClick: () => togglePublish(row),
      }, () => row.is_published ? '下架' : '上架'),
      h(NButton, { size: 'small', type: 'error', onClick: () => confirmDelete(row) }, () => '刪除'),
    ]),
  },
]

onMounted(() => load(1))
</script>
