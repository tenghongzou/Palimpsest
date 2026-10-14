<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">橫幅管理</h1>
      <n-button type="primary" @click="openCreate">新增橫幅</n-button>
    </div>

    <n-data-table
      :columns="columns"
      :data="sortedBanners"
      :loading="loading"
      :row-key="(row: ApiBanner) => row.id"
      :scroll-x="1000"
    />

    <n-modal v-model:show="modalOpen" preset="card" :title="form.id ? '編輯橫幅' : '新增橫幅'" class="max-w-2xl" :mask-closable="false">
      <n-form label-placement="left" label-width="90">
        <n-form-item label="標題">
          <n-input v-model:value="form.title" placeholder="橫幅標題" maxlength="200" />
        </n-form-item>
        <n-form-item label="圖片">
          <AdminImageUpload v-model="form.image_url" kind="banners" />
        </n-form-item>
        <n-form-item label="連結類型">
          <n-select v-model:value="form.link_type" :options="linkTypeOptions" placeholder="不連結" clearable />
        </n-form-item>
        <n-form-item v-if="form.link_type" label="連結目標">
          <n-input v-model:value="form.link_value" :placeholder="linkPlaceholder" maxlength="500" />
        </n-form-item>
        <n-form-item label="排序">
          <n-input-number v-model:value="form.sort_order" :min="0" />
        </n-form-item>
        <n-form-item label="啟用">
          <n-switch v-model:value="form.is_active" />
        </n-form-item>
        <n-form-item label="開始時間">
          <n-date-picker v-model:value="form.start_at" type="datetime" clearable placeholder="立即" class="w-full" />
        </n-form-item>
        <n-form-item label="結束時間">
          <n-date-picker v-model:value="form.end_at" type="datetime" clearable placeholder="不限" class="w-full" />
        </n-form-item>
      </n-form>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="modalOpen = false">取消</n-button>
          <n-button type="primary" :loading="saving" @click="save">儲存橫幅</n-button>
        </div>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import {
  NButton, NDataTable, NDatePicker, NForm, NFormItem, NInput, NInputNumber, NModal, NSelect, NSpace, NSwitch, NTag,
  useDialog, useMessage,
} from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { h } from 'vue'
import type { ApiResponse } from '~/utils/api'
import type { ApiBanner, ApiBannerInput } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })
useHead({ title: '橫幅管理 — Palimpsest' })

type LinkType = NonNullable<ApiBannerInput['link_type']>

const message = useMessage()
const dialog = useDialog()

const banners = ref<ApiBanner[]>([])
const loading = ref(false)

const sortedBanners = computed(() => [...banners.value].sort((a, b) => a.sort_order - b.sort_order))

const linkTypeOptions: { label: string, value: LinkType }[] = [
  { label: '小說', value: 'novel' },
  { label: '分類', value: 'category' },
  { label: '網址', value: 'url' },
]

const linkPlaceholder = computed(() => ({
  novel: '小說 ID',
  category: '分類代稱（slug）',
  url: 'https://…',
})[form.link_type ?? 'url'])

async function load() {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiBanner[]>>('/admin/banners')
    banners.value = res.data
  }
  catch (error) {
    message.error(describeError(error, {}, '載入橫幅失敗'))
  }
  finally {
    loading.value = false
  }
}

const modalOpen = ref(false)
const saving = ref(false)
const form = reactive({
  id: '',
  title: '',
  image_url: '',
  link_type: null as LinkType | null,
  link_value: '',
  sort_order: 0 as number | null,
  is_active: true,
  start_at: null as number | null,
  end_at: null as number | null,
})

const toMillis = (iso?: string) => (iso ? new Date(iso).getTime() : null)

function openCreate() {
  Object.assign(form, {
    id: '', title: '', image_url: '', link_type: null, link_value: '',
    sort_order: banners.value.length, is_active: true, start_at: null, end_at: null,
  })
  modalOpen.value = true
}

function openEdit(row: ApiBanner) {
  Object.assign(form, {
    id: row.id,
    title: row.title,
    image_url: row.image_url,
    link_type: row.link_type ?? null,
    link_value: row.link_value ?? '',
    sort_order: row.sort_order,
    is_active: row.is_active,
    start_at: toMillis(row.start_at),
    end_at: toMillis(row.end_at),
  })
  modalOpen.value = true
}

async function save() {
  if (!form.title.trim() || !form.image_url.trim()) {
    message.warning('請填寫標題並上傳圖片')
    return
  }
  if (form.start_at && form.end_at && form.end_at <= form.start_at) {
    message.warning('結束時間必須晚於開始時間')
    return
  }
  const body: ApiBannerInput = {
    title: form.title.trim(),
    image_url: form.image_url.trim(),
    link_type: form.link_type ?? undefined,
    link_value: form.link_type ? form.link_value.trim() : undefined,
    sort_order: form.sort_order ?? 0,
    is_active: form.is_active,
    start_at: form.start_at ? new Date(form.start_at).toISOString() : undefined,
    end_at: form.end_at ? new Date(form.end_at).toISOString() : undefined,
  }
  saving.value = true
  try {
    if (form.id) await apiFetch(`/admin/banners/${form.id}`, { method: 'PUT', body })
    else await apiFetch('/admin/banners', { method: 'POST', body })
    message.success('橫幅已儲存')
    modalOpen.value = false
    await load()
  }
  catch (error) {
    message.error(describeError(error, {}, '儲存失敗'))
  }
  finally {
    saving.value = false
  }
}

function confirmDelete(row: ApiBanner) {
  dialog.warning({
    title: '刪除橫幅',
    content: `確定要刪除「${row.title}」嗎？`,
    positiveText: '刪除',
    negativeText: '取消',
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/banners/${row.id}`, { method: 'DELETE' })
        message.success('已刪除')
        await load()
      }
      catch (error) {
        message.error(describeError(error, {}, '刪除失敗'))
      }
    },
  })
}

function scheduleLabel(row: ApiBanner) {
  if (!row.start_at && !row.end_at) return '不限'
  return `${row.start_at ? adminDateTime(row.start_at) : '立即'} ～ ${row.end_at ? adminDateTime(row.end_at) : '不限'}`
}

const columns: DataTableColumns<ApiBanner> = [
  {
    title: '圖片',
    key: 'image_url',
    width: 140,
    render: row => h('img', { src: row.image_url, alt: row.title, class: 'h-12 rounded object-cover' }),
  },
  { title: '標題', key: 'title', minWidth: 160 },
  {
    title: '連結',
    key: 'link_value',
    minWidth: 180,
    render: row => row.link_type
      ? `${linkTypeOptions.find(o => o.value === row.link_type)?.label}：${row.link_value ?? ''}`
      : '—',
  },
  { title: '排序', key: 'sort_order', width: 70 },
  {
    title: '狀態',
    key: 'is_active',
    width: 80,
    render: row => h(NTag, { size: 'small', type: row.is_active ? 'success' : 'default' }, () => row.is_active ? '啟用' : '停用'),
  },
  { title: '排程', key: 'start_at', minWidth: 220, render: row => scheduleLabel(row) },
  {
    title: '操作',
    key: 'actions',
    width: 140,
    render: row => h(NSpace, { size: 'small' }, () => [
      h(NButton, { size: 'small', onClick: () => openEdit(row) }, () => '編輯'),
      h(NButton, { size: 'small', type: 'error', onClick: () => confirmDelete(row) }, () => '刪除'),
    ]),
  },
]

onMounted(load)
</script>
