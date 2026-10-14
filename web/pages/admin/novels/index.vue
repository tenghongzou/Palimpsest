<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">{{ $t('admin.menu.novels') }}</h1>
      <n-button type="primary" @click="router.push('/admin/novels/new')">{{ $t('admin.novels.create') }}</n-button>
    </div>

    <div class="flex flex-wrap items-center gap-3">
      <n-input
        v-model:value="filters.q"
        :placeholder="$t('admin.novels.searchPlaceholder')"
        clearable
        class="max-w-64"
        @keyup.enter="load(1)"
        @clear="clearSearch"
      />
      <n-select
        v-model:value="filters.status"
        :options="novelStatusOptions"
        :placeholder="$t('category.allStatuses')"
        clearable
        class="w-32"
        @update:value="load(1)"
      />
      <n-select
        v-model:value="filters.is_published"
        :options="publishedOptions"
        :placeholder="$t('admin.novels.publishState')"
        clearable
        class="w-32"
        @update:value="load(1)"
      />
      <n-button @click="load(1)">{{ $t('common.search') }}</n-button>
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

const { t } = useI18n()
const { novelStatusOptions, novelStatusLabel, dateTime } = useAdminLabels()
useHead({ title: () => t('admin.menu.novels') })

const router = useRouter()
const message = useMessage()
const dialog = useDialog()

const { items, loading, filters, tablePagination, load } = useAdminList<ApiNovel, {
  q: string
  status: string | null
  is_published: string | null
}>('/admin/novels', { q: '', status: null, is_published: null })

const publishedOptions = computed(() => [
  { label: t('admin.novels.published'), value: 'true' },
  { label: t('admin.novels.unpublished'), value: 'false' },
])

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
    message.success(publish ? t('admin.novels.published') : t('admin.novels.unpublishedToast'))
    await load()
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('common.operationFailed')))
  }
}

function confirmDelete(novel: ApiNovel) {
  dialog.warning({
    title: t('admin.novels.delete'),
    content: t('admin.novels.confirmDelete', { name: novel.title }),
    positiveText: t('common.delete'),
    negativeText: t('common.cancel'),
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/novels/${novel.id}`, { method: 'DELETE' })
        message.success(t('common.deleted'))
        await load()
      }
      catch (error) {
        message.error(describeError(t, error, {}, t('common.deleteFailed')))
      }
    },
  })
}

const columns = computed<DataTableColumns<ApiNovel>>(() => [
  {
    title: t('admin.novels.title'),
    key: 'title',
    minWidth: 180,
    render: row => h('a', {
      class: 'text-primary cursor-pointer',
      onClick: () => router.push(`/admin/novels/${row.id}`),
    }, row.title),
  },
  { title: t('admin.novels.author'), key: 'author_name', width: 120 },
  {
    title: t('admin.columns.status'),
    key: 'status',
    width: 90,
    render: row => novelStatusLabel(row.status),
  },
  {
    title: t('admin.novels.publishColumn'),
    key: 'is_published',
    width: 90,
    render: row => h(NTag, { size: 'small', type: row.is_published ? 'success' : 'default' }, () => row.is_published ? t('admin.novels.published') : t('admin.novels.unpublished')),
  },
  {
    title: t('admin.novels.featured'),
    key: 'is_featured',
    width: 70,
    render: row => row.is_featured ? t('common.yes') : '',
  },
  { title: t('admin.reports.targets.chapter'), key: 'total_chapters', width: 70 },
  { title: t('admin.columns.updatedAt'), key: 'updated_at', width: 170, render: row => dateTime(row.updated_at) },
  {
    title: t('admin.columns.actions'),
    key: 'actions',
    width: 260,
    render: row => h(NSpace, { size: 'small' }, () => [
      h(NButton, { size: 'small', onClick: () => router.push(`/admin/novels/${row.id}`) }, () => t('common.edit')),
      h(NButton, { size: 'small', onClick: () => router.push(`/admin/novels/${row.id}/chapters`) }, () => t('admin.reports.targets.chapter')),
      h(NButton, {
        size: 'small',
        type: row.is_published ? 'warning' : 'primary',
        onClick: () => togglePublish(row),
      }, () => row.is_published ? t('admin.novels.unpublish') : t('admin.novels.publish')),
      h(NButton, { size: 'small', type: 'error', onClick: () => confirmDelete(row) }, () => t('common.delete')),
    ]),
  },
])

onMounted(() => load(1))
</script>
