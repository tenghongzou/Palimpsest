<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">{{ $t('admin.menu.categories') }}</h1>
      <n-button type="primary" @click="openCreate(null)">{{ $t('admin.categories.create') }}</n-button>
    </div>

    <n-data-table
      :columns="columns"
      :data="tree"
      :loading="loading"
      :row-key="(row: CategoryRow) => row.id"
      default-expand-all
      children-key="children"
      :scroll-x="800"
    />

    <n-modal v-model:show="modalOpen" preset="card" :title="form.id ? $t('admin.categories.edit') : $t('admin.categories.create')" class="max-w-lg" :mask-closable="false">
      <n-form label-placement="left" :label-width="locale === 'en' ? 110 : 80">
        <n-form-item :label="$t('admin.categories.parent')">
          <n-select
            v-model:value="form.parent_id"
            :options="parentOptions"
            :disabled="hasChildren(form.id)"
            :placeholder="$t('admin.categories.noParent')"
            clearable
          />
        </n-form-item>
        <n-form-item :label="$t('admin.columns.name')">
          <n-input v-model:value="form.name" :placeholder="$t('admin.categories.namePlaceholder')" maxlength="50" />
        </n-form-item>
        <n-form-item :label="$t('admin.columns.slug')">
          <n-input v-model:value="form.slug" :placeholder="$t('admin.categories.slugPlaceholder')" maxlength="50" />
        </n-form-item>
        <n-form-item :label="$t('admin.categories.iconUrl')">
          <n-input v-model:value="form.icon_url" :placeholder="$t('admin.optional')" />
        </n-form-item>
        <n-form-item :label="$t('admin.columns.sortOrder')">
          <n-input-number v-model:value="form.sort_order" :min="0" />
        </n-form-item>
        <n-form-item :label="$t('admin.enabled')">
          <n-switch v-model:value="form.is_active" />
        </n-form-item>
      </n-form>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="modalOpen = false">{{ $t('common.cancel') }}</n-button>
          <n-button type="primary" :loading="saving" @click="save">{{ $t('admin.categories.save') }}</n-button>
        </div>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import {
  NButton, NDataTable, NForm, NFormItem, NInput, NInputNumber, NModal, NSelect, NSpace, NSwitch, NTag,
  useDialog, useMessage,
} from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { h } from 'vue'
import type { ApiResponse } from '~/utils/api'
import type { ApiCategory, ApiCategoryInput } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })

const { t, locale } = useI18n()
useHead({ title: () => t('admin.menu.categories') })

type CategoryRow = ApiCategory & { children?: CategoryRow[] }

const message = useMessage()
const dialog = useDialog()

const categories = ref<ApiCategory[]>([])
const loading = ref(false)

const bySort = (a: ApiCategory, b: ApiCategory) => (a.sort_order ?? 0) - (b.sort_order ?? 0) || a.id - b.id

const tree = computed<CategoryRow[]>(() => {
  const tops = categories.value.filter(c => !c.parent_id || !categories.value.some(p => p.id === c.parent_id))
  return [...tops].sort(bySort).map((p) => {
    const children = categories.value.filter(c => c.parent_id === p.id).sort(bySort)
    return { ...p, children: children.length ? children.map(c => ({ ...c, children: undefined })) : undefined }
  })
})

function hasChildren(id: number | null) {
  return id !== null && categories.value.some(c => c.parent_id === id)
}

const parentOptions = computed(() => categories.value
  .filter(c => !c.parent_id && c.id !== form.id)
  .sort(bySort)
  .map(c => ({ label: c.name, value: c.id })))

async function load() {
  loading.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiCategory[]>>('/admin/categories')
    categories.value = res.data
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('admin.categories.loadFailed')))
  }
  finally {
    loading.value = false
  }
}

const modalOpen = ref(false)
const saving = ref(false)
const form = reactive({
  id: null as number | null,
  parent_id: null as number | null,
  name: '',
  slug: '',
  icon_url: '',
  sort_order: 0 as number | null,
  is_active: true,
})

function openCreate(parentId: number | null) {
  Object.assign(form, { id: null, parent_id: parentId, name: '', slug: '', icon_url: '', sort_order: 0, is_active: true })
  modalOpen.value = true
}

function openEdit(row: ApiCategory) {
  Object.assign(form, {
    id: row.id,
    parent_id: row.parent_id ?? null,
    name: row.name,
    slug: row.slug,
    icon_url: row.icon_url ?? '',
    sort_order: row.sort_order ?? 0,
    is_active: row.is_active !== false,
  })
  modalOpen.value = true
}

async function save() {
  if (!form.name.trim() || !form.slug.trim()) {
    message.warning(t('admin.categories.required'))
    return
  }
  const body: ApiCategoryInput = {
    name: form.name.trim(),
    slug: form.slug.trim(),
    icon_url: form.icon_url.trim() || undefined,
    sort_order: form.sort_order ?? 0,
    is_active: form.is_active,
    parent_id: form.parent_id ?? undefined,
  }
  saving.value = true
  try {
    if (form.id) await apiFetch(`/admin/categories/${form.id}`, { method: 'PUT', body })
    else await apiFetch('/admin/categories', { method: 'POST', body })
    message.success(t('admin.categories.saved'))
    modalOpen.value = false
    await load()
  }
  catch (error) {
    message.error(statusOf(error) === 409 ? t('admin.categories.slugTaken') : describeError(t, error, {}, t('common.saveFailed')))
  }
  finally {
    saving.value = false
  }
}

function confirmDelete(row: ApiCategory) {
  if (hasChildren(row.id)) {
    message.warning(t('admin.categories.hasChildren'))
    return
  }
  dialog.warning({
    title: t('admin.categories.delete'),
    content: t('admin.confirmDeleteNamed', { name: row.name }),
    positiveText: t('common.delete'),
    negativeText: t('common.cancel'),
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/categories/${row.id}`, { method: 'DELETE' })
        message.success(t('common.deleted'))
        await load()
      }
      catch (error) {
        message.error(statusOf(error) === 409 ? t('admin.categories.deleteHasChildren') : describeError(t, error, {}, t('common.deleteFailed')))
      }
    },
  })
}

const columns = computed<DataTableColumns<CategoryRow>>(() => [
  { title: t('admin.columns.name'), key: 'name', minWidth: 180 },
  { title: t('admin.columns.slug'), key: 'slug', width: 180 },
  { title: t('admin.columns.sortOrder'), key: 'sort_order', width: 70 },
  {
    title: t('admin.columns.status'),
    key: 'is_active',
    width: 80,
    render: row => h(NTag, { size: 'small', type: row.is_active === false ? 'default' : 'success' }, () => row.is_active === false ? t('admin.disabled') : t('admin.enabled')),
  },
  {
    title: t('admin.columns.actions'),
    key: 'actions',
    width: 230,
    render: row => h(NSpace, { size: 'small' }, () => [
      h(NButton, { size: 'small', onClick: () => openEdit(row) }, () => t('common.edit')),
      row.parent_id ? null : h(NButton, { size: 'small', onClick: () => openCreate(row.id) }, () => t('admin.categories.createChild')),
      h(NButton, { size: 'small', type: 'error', onClick: () => confirmDelete(row) }, () => t('common.delete')),
    ]),
  },
])

onMounted(load)
</script>
