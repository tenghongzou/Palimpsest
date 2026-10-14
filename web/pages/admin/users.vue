<template>
  <div class="space-y-4">
    <h1 class="text-xl font-bold">{{ $t('admin.menu.users') }}</h1>

    <div class="flex flex-wrap items-center gap-3">
      <n-input
        v-model:value="filters.q"
        :placeholder="$t('admin.users.searchPlaceholder')"
        clearable
        class="max-w-72"
        @keyup.enter="load(1)"
        @clear="clearSearch"
      />
      <n-select
        v-model:value="filters.status"
        :options="statusOptions"
        :placeholder="$t('category.allStatuses')"
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

const { t } = useI18n()
const { dateTime } = useAdminLabels()
useHead({ title: () => t('admin.menu.users') })

const message = useMessage()
const dialog = useDialog()
const authStore = useAuthStore()

const { items, loading, filters, tablePagination, load } = useAdminList<ApiUser, {
  q: string
  status: string | null
}>('/admin/users', { q: '', status: null })

const statusOptions = computed(() => [
  { label: t('admin.users.status.active'), value: 'active' },
  { label: t('admin.users.status.banned'), value: 'banned' },
])

const ROLES = ['reader', 'author', 'admin', 'super_admin']
const roleLabel = (role: string) => (ROLES.includes(role) ? t(`admin.users.roles.${role}`) : role)

function clearSearch() {
  filters.q = ''
  void load(1)
}

function setStatus(user: ApiUser, status: 'active' | 'banned') {
  const ban = status === 'banned'
  const name = user.nickname || user.username
  dialog[ban ? 'warning' : 'info']({
    title: ban ? t('admin.users.ban') : t('admin.users.unban'),
    content: ban ? t('admin.users.confirmBan', { name }) : t('admin.users.confirmUnban', { name }),
    positiveText: ban ? t('admin.users.banShort') : t('admin.users.unban'),
    negativeText: t('common.cancel'),
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/users/${user.id}/status`, { method: 'PUT', body: { status } })
        message.success(ban ? t('admin.users.banned') : t('admin.users.unbanned'))
        await load()
      }
      catch (error) {
        message.error(describeError(t, error, {}, t('common.operationFailed')))
      }
    },
  })
}

const columns = computed<DataTableColumns<ApiUser>>(() => [
  {
    title: t('admin.users.columns.user'),
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
  { title: t('auth.email'), key: 'email', minWidth: 180 },
  { title: t('admin.users.columns.role'), key: 'role', width: 100, render: row => roleLabel(row.role) },
  {
    title: t('admin.columns.status'),
    key: 'status',
    width: 90,
    render: row => h(NTag, { size: 'small', type: row.status === 'banned' ? 'error' : 'success' }, () => row.status === 'banned' ? t('admin.users.status.banned') : t('admin.users.status.active')),
  },
  { title: t('admin.users.columns.registered'), key: 'created_at', width: 170, render: row => dateTime(row.created_at) },
  { title: t('admin.users.columns.lastLogin'), key: 'last_login_at', width: 170, render: row => dateTime(row.last_login_at) },
  {
    title: t('admin.columns.actions'),
    key: 'actions',
    width: 110,
    render: (row) => {
      if (row.id === authStore.user?.id) return h('span', { class: 'text-xs text-gray-400' }, t('admin.users.currentAccount'))
      return row.status === 'banned'
        ? h(NButton, { size: 'small', onClick: () => setStatus(row, 'active') }, () => t('admin.users.unban'))
        : h(NButton, { size: 'small', type: 'error', onClick: () => setStatus(row, 'banned') }, () => t('admin.users.banShort'))
    },
  },
])

onMounted(() => load(1))
</script>
