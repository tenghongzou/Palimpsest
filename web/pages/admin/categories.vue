<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">分類管理</h1>
      <n-button type="primary" @click="openCreate(null)">新增分類</n-button>
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

    <n-modal v-model:show="modalOpen" preset="card" :title="form.id ? '編輯分類' : '新增分類'" class="max-w-lg" :mask-closable="false">
      <n-form label-placement="left" label-width="80">
        <n-form-item label="上層分類">
          <n-select
            v-model:value="form.parent_id"
            :options="parentOptions"
            :disabled="hasChildren(form.id)"
            placeholder="無（頂層分類）"
            clearable
          />
        </n-form-item>
        <n-form-item label="名稱">
          <n-input v-model:value="form.name" placeholder="分類名稱" maxlength="50" />
        </n-form-item>
        <n-form-item label="代稱">
          <n-input v-model:value="form.slug" placeholder="英文代稱，例如 xuanhuan" maxlength="50" />
        </n-form-item>
        <n-form-item label="圖示網址">
          <n-input v-model:value="form.icon_url" placeholder="選填" />
        </n-form-item>
        <n-form-item label="排序">
          <n-input-number v-model:value="form.sort_order" :min="0" />
        </n-form-item>
        <n-form-item label="啟用">
          <n-switch v-model:value="form.is_active" />
        </n-form-item>
      </n-form>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="modalOpen = false">取消</n-button>
          <n-button type="primary" :loading="saving" @click="save">儲存分類</n-button>
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
useHead({ title: '分類管理 — Palimpsest' })

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
    message.error(describeError(error, {}, '載入分類失敗'))
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
    message.warning('請填寫名稱與代稱')
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
    message.success('分類已儲存')
    modalOpen.value = false
    await load()
  }
  catch (error) {
    message.error(statusOf(error) === 409 ? '代稱已被其他分類使用' : describeError(error, {}, '儲存失敗'))
  }
  finally {
    saving.value = false
  }
}

function confirmDelete(row: ApiCategory) {
  if (hasChildren(row.id)) {
    message.warning('請先刪除或移動此分類下的子分類')
    return
  }
  dialog.warning({
    title: '刪除分類',
    content: `確定要刪除「${row.name}」嗎？`,
    positiveText: '刪除',
    negativeText: '取消',
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/categories/${row.id}`, { method: 'DELETE' })
        message.success('已刪除')
        await load()
      }
      catch (error) {
        message.error(statusOf(error) === 409 ? '此分類仍有子分類，無法刪除' : describeError(error, {}, '刪除失敗'))
      }
    },
  })
}

const columns: DataTableColumns<CategoryRow> = [
  { title: '名稱', key: 'name', minWidth: 180 },
  { title: '代稱', key: 'slug', width: 180 },
  { title: '排序', key: 'sort_order', width: 70 },
  {
    title: '狀態',
    key: 'is_active',
    width: 80,
    render: row => h(NTag, { size: 'small', type: row.is_active === false ? 'default' : 'success' }, () => row.is_active === false ? '停用' : '啟用'),
  },
  {
    title: '操作',
    key: 'actions',
    width: 230,
    render: row => h(NSpace, { size: 'small' }, () => [
      h(NButton, { size: 'small', onClick: () => openEdit(row) }, () => '編輯'),
      row.parent_id ? null : h(NButton, { size: 'small', onClick: () => openCreate(row.id) }, () => '新增子分類'),
      h(NButton, { size: 'small', type: 'error', onClick: () => confirmDelete(row) }, () => '刪除'),
    ]),
  },
]

onMounted(load)
</script>
