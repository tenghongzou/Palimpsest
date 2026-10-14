<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">{{ $t('admin.menu.banners') }}</h1>
      <n-button type="primary" @click="openCreate">{{ $t('admin.banners.create') }}</n-button>
    </div>

    <n-data-table
      :columns="columns"
      :data="sortedBanners"
      :loading="loading"
      :row-key="(row: ApiBanner) => row.id"
      :scroll-x="1000"
    />

    <n-modal v-model:show="modalOpen" preset="card" :title="form.id ? $t('admin.banners.edit') : $t('admin.banners.create')" class="max-w-2xl" :mask-closable="false">
      <n-form label-placement="left" :label-width="locale === 'en' ? 110 : 90">
        <n-form-item :label="$t('admin.columns.title')">
          <n-input v-model:value="form.title" :placeholder="$t('admin.banners.titlePlaceholder')" maxlength="200" />
        </n-form-item>
        <n-form-item :label="$t('admin.columns.image')">
          <AdminImageUpload v-model="form.image_url" kind="banners" />
        </n-form-item>
        <n-form-item :label="$t('admin.banners.linkType')">
          <n-select v-model:value="form.link_type" :options="linkTypeOptions" :placeholder="$t('admin.banners.noLink')" clearable />
        </n-form-item>
        <n-form-item v-if="form.link_type" :label="$t('admin.banners.linkTarget')">
          <n-input v-model:value="form.link_value" :placeholder="linkPlaceholder" maxlength="500" />
        </n-form-item>
        <n-form-item :label="$t('admin.columns.sortOrder')">
          <n-input-number v-model:value="form.sort_order" :min="0" />
        </n-form-item>
        <n-form-item :label="$t('admin.enabled')">
          <n-switch v-model:value="form.is_active" />
        </n-form-item>
        <n-form-item :label="$t('admin.banners.startAt')">
          <n-date-picker v-model:value="form.start_at" type="datetime" clearable :placeholder="$t('admin.banners.immediately')" class="w-full" />
        </n-form-item>
        <n-form-item :label="$t('admin.banners.endAt')">
          <n-date-picker v-model:value="form.end_at" type="datetime" clearable :placeholder="$t('admin.banners.noLimit')" class="w-full" />
        </n-form-item>
      </n-form>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="modalOpen = false">{{ $t('common.cancel') }}</n-button>
          <n-button type="primary" :loading="saving" @click="save">{{ $t('admin.banners.save') }}</n-button>
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

const { t, locale } = useI18n()
const { dateTime } = useAdminLabels()
useHead({ title: () => t('admin.menu.banners') })

type LinkType = NonNullable<ApiBannerInput['link_type']>

const message = useMessage()
const dialog = useDialog()

const banners = ref<ApiBanner[]>([])
const loading = ref(false)

const sortedBanners = computed(() => [...banners.value].sort((a, b) => a.sort_order - b.sort_order))

const linkTypeOptions = computed(() => (['novel', 'category', 'url'] as LinkType[]).map(value => ({ label: t(`admin.banners.linkTypes.${value}`), value })))

const linkPlaceholder = computed(() => t(`admin.banners.linkPlaceholders.${form.link_type ?? 'url'}`))

async function load() {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiBanner[]>>('/admin/banners')
    banners.value = res.data
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('admin.banners.loadFailed')))
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
    message.warning(t('admin.banners.required'))
    return
  }
  if (form.start_at && form.end_at && form.end_at <= form.start_at) {
    message.warning(t('admin.banners.endBeforeStart'))
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
    message.success(t('admin.banners.saved'))
    modalOpen.value = false
    await load()
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('common.saveFailed')))
  }
  finally {
    saving.value = false
  }
}

function confirmDelete(row: ApiBanner) {
  dialog.warning({
    title: t('admin.banners.delete'),
    content: t('admin.confirmDeleteNamed', { name: row.title }),
    positiveText: t('common.delete'),
    negativeText: t('common.cancel'),
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/banners/${row.id}`, { method: 'DELETE' })
        message.success(t('common.deleted'))
        await load()
      }
      catch (error) {
        message.error(describeError(t, error, {}, t('common.deleteFailed')))
      }
    },
  })
}

function scheduleLabel(row: ApiBanner) {
  if (!row.start_at && !row.end_at) return t('admin.banners.noLimit')
  return t('admin.banners.schedule', {
    start: row.start_at ? dateTime(row.start_at) : t('admin.banners.immediately'),
    end: row.end_at ? dateTime(row.end_at) : t('admin.banners.noLimit'),
  })
}

const columns = computed<DataTableColumns<ApiBanner>>(() => [
  {
    title: t('admin.columns.image'),
    key: 'image_url',
    width: 140,
    render: row => h('img', { src: row.image_url, alt: row.title, class: 'h-12 rounded object-cover' }),
  },
  { title: t('admin.columns.title'), key: 'title', minWidth: 160 },
  {
    title: t('admin.banners.link'),
    key: 'link_value',
    minWidth: 180,
    render: row => row.link_type
      ? t('admin.banners.linkValue', { type: t(`admin.banners.linkTypes.${row.link_type}`), value: row.link_value ?? '' })
      : '—',
  },
  { title: t('admin.columns.sortOrder'), key: 'sort_order', width: 70 },
  {
    title: t('admin.columns.status'),
    key: 'is_active',
    width: 80,
    render: row => h(NTag, { size: 'small', type: row.is_active ? 'success' : 'default' }, () => row.is_active ? t('admin.enabled') : t('admin.disabled')),
  },
  { title: t('admin.banners.scheduleColumn'), key: 'start_at', minWidth: 220, render: row => scheduleLabel(row) },
  {
    title: t('admin.columns.actions'),
    key: 'actions',
    width: 140,
    render: row => h(NSpace, { size: 'small' }, () => [
      h(NButton, { size: 'small', onClick: () => openEdit(row) }, () => t('common.edit')),
      h(NButton, { size: 'small', type: 'error', onClick: () => confirmDelete(row) }, () => t('common.delete')),
    ]),
  },
])

onMounted(load)
</script>
