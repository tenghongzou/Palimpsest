<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">用戶管理</h1>

    <div class="flex flex-wrap items-center gap-3">
      <n-input
        v-model:value="filters.q"
        placeholder="搜尋帳號、電子郵件或暱稱"
        clearable
        class="max-w-72"
        @keyup.enter="load(1)"
        @clear="clearSearch"
      />
      <n-select
        v-model:value="filters.status"
        :options="statusOptions"
        placeholder="全部狀態"
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
      :row-key="(row: ApiUser) => row.id"
      :scroll-x="900"
    />
  </div>
</template>

<script setup lang="ts">
import { NAvatar, NButton, NDataTable, NInput, NSelect, NTag, useDialog, useMessage } from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { h } from 'vue'
import type { ApiUser } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })
useHead({ title: '用戶管理 — Palimpsest' })

const message = useMessage()
const dialog = useDialog()
const authStore = useAuthStore()

const { items, loading, filters, tablePagination, load } = useAdminList<ApiUser, {
  q: string
  status: string | null
}>('/admin/users', { q: '', status: null })

const statusOptions = [
  { label: '正常', value: 'active' },
  { label: '已停權', value: 'banned' },
]

const roleLabels: Record<string, string> = {
  reader: '讀者',
  author: '作者',
  admin: '管理員',
  super_admin: '超級管理員',
}

function clearSearch() {
  filters.q = ''
  void load(1)
}

function setStatus(user: ApiUser, status: 'active' | 'banned') {
  const ban = status === 'banned'
  dialog[ban ? 'warning' : 'info']({
    title: ban ? '停權用戶' : '解除停權',
    content: ban
      ? `確定要停權「${user.nickname || user.username}」嗎？停權後該用戶無法登入。`
      : `確定要恢復「${user.nickname || user.username}」的帳號嗎？`,
    positiveText: ban ? '停權' : '解除停權',
    negativeText: '取消',
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/users/${user.id}/status`, { method: 'PUT', body: { status } })
        message.success(ban ? '已停權' : '已解除停權')
        await load()
      }
      catch (error) {
        message.error(describeError(error, {}, '操作失敗'))
      }
    },
  })
}

const columns: DataTableColumns<ApiUser> = [
  {
    title: '用戶',
    key: 'username',
    minWidth: 200,
    render: row => h('div', { class: 'flex items-center gap-2' }, [
      h(NAvatar, { round: true, size: 'small', src: row.avatar_url || undefined }, () => (row.nickname || row.username).slice(0, 1)),
      h('div', [
        h('div', row.nickname || row.username),
        h('div', { class: 'text-xs text-gray-400' }, `@${row.username}`),
      ]),
    ]),
  },
  { title: '電子郵件', key: 'email', minWidth: 180 },
  { title: '角色', key: 'role', width: 100, render: row => roleLabels[row.role] ?? row.role },
  {
    title: '狀態',
    key: 'status',
    width: 90,
    render: row => h(NTag, { size: 'small', type: row.status === 'banned' ? 'error' : 'success' }, () => row.status === 'banned' ? '已停權' : '正常'),
  },
  { title: '註冊時間', key: 'created_at', width: 170, render: row => adminDateTime(row.created_at) },
  { title: '最後登入', key: 'last_login_at', width: 170, render: row => adminDateTime(row.last_login_at) },
  {
    title: '操作',
    key: 'actions',
    width: 110,
    render: (row) => {
      if (row.id === authStore.user?.id) return h('span', { class: 'text-xs text-gray-400' }, '目前帳號')
      return row.status === 'banned'
        ? h(NButton, { size: 'small', onClick: () => setStatus(row, 'active') }, () => '解除停權')
        : h(NButton, { size: 'small', type: 'error', onClick: () => setStatus(row, 'banned') }, () => '停權')
    },
  },
]

onMounted(() => load(1))
</script>
