<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <n-button text @click="router.push(`/admin/novels/${novelId}`)">{{ $t('admin.chapters.backToNovel') }}</n-button>
        <h1 class="text-xl font-bold">{{ $t('admin.chapters.title') }}<span v-if="novelTitle" class="text-gray-500 font-normal">{{ $t('admin.reports.colon') }}{{ novelTitle }}</span></h1>
      </div>
      <div class="flex gap-2">
        <n-button @click="openImport">{{ $t('admin.chapters.batchImport') }}</n-button>
        <n-button type="primary" @click="openCreate">{{ $t('admin.chapters.create') }}</n-button>
      </div>
    </div>

    <n-data-table
      :columns="columns"
      :data="chapters"
      :loading="loading"
      :row-key="(row: ApiChapter) => row.id"
      :pagination="{ pageSize: 50 }"
      :scroll-x="800"
    />

    <!-- Chapter editor -->
    <n-modal
      v-model:show="editorOpen"
      preset="card"
      :title="editing.id ? $t('admin.chapters.edit') : $t('admin.chapters.create')"
      class="max-w-3xl"
      :mask-closable="false"
    >
      <n-spin :show="editorLoading">
        <n-form label-placement="left" :label-width="locale === 'en' ? 120 : 80">
          <n-form-item :label="$t('admin.chapters.number')">
            <n-input-number v-model:value="editing.chapter_number" :min="1" :placeholder="$t('admin.chapters.number')" />
          </n-form-item>
          <n-form-item :label="$t('admin.columns.title')">
            <n-input v-model:value="editing.title" :placeholder="$t('admin.chapters.titlePlaceholder')" maxlength="200" />
          </n-form-item>
          <n-form-item :label="$t('admin.columns.content')">
            <n-input
              v-model:value="editing.content"
              type="textarea"
              :placeholder="$t('admin.chapters.contentPlaceholder')"
              :autosize="{ minRows: 10, maxRows: 24 }"
            />
          </n-form-item>
          <n-form-item :label="$t('admin.chapters.publish')">
            <n-switch v-model:value="editing.is_published" />
            <span class="ml-6 mr-2">{{ $t('admin.chapters.free') }}</span>
            <n-switch v-model:value="editing.is_free" />
          </n-form-item>
        </n-form>
      </n-spin>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="editorOpen = false">{{ $t('common.cancel') }}</n-button>
          <n-button type="primary" :loading="saving" @click="saveChapter">{{ $t('admin.chapters.save') }}</n-button>
        </div>
      </template>
    </n-modal>

    <!-- Batch import -->
    <n-modal v-model:show="importOpen" preset="card" :title="$t('admin.import.title')" class="max-w-4xl" :mask-closable="false">
      <div class="space-y-3">
        <p class="text-sm text-gray-500">
          <i18n-t keypath="admin.import.help" scope="global">
            <template #example>
              <code>[{"title": "...", "content": "...", "chapter_number": 1}]</code>
            </template>
            <template #max>{{ MAX_IMPORT_CHAPTERS }}</template>
          </i18n-t>
        </p>
        <n-input
          v-model:value="importText"
          type="textarea"
          :placeholder="$t('admin.import.placeholder')"
          :autosize="{ minRows: 8, maxRows: 16 }"
          data-testid="import-text"
        />
        <div class="flex items-center gap-6 text-sm">
          <span class="flex items-center gap-2">{{ $t('admin.chapters.publish') }} <n-switch v-model:value="importPublished" /></span>
          <span class="flex items-center gap-2">{{ $t('admin.chapters.free') }} <n-switch v-model:value="importFree" /></span>
          <span class="text-gray-500">{{ $t('admin.import.startNumber', { n: nextNumber }) }}</span>
        </div>
        <n-alert v-if="importProblems.length" type="error" :show-icon="false">
          <div v-for="(e, i) in importProblems.slice(0, 10)" :key="i">{{ e }}</div>
          <div v-if="importProblems.length > 10">{{ $t('admin.import.moreProblems', { n: importProblems.length - 10 }) }}</div>
        </n-alert>
        <div v-if="parsed.chapters.length" class="text-sm">
          {{ $t('admin.import.preview', { n: parsed.chapters.length }, parsed.chapters.length) }}
          <n-data-table
            size="small"
            class="mt-2"
            :columns="previewColumns"
            :data="parsed.chapters"
            :max-height="240"
            :row-key="(row: ImportedChapter) => row.chapter_number"
          />
        </div>
      </div>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="importOpen = false">{{ $t('common.cancel') }}</n-button>
          <n-button
            type="primary"
            :loading="importing"
            :disabled="!parsed.chapters.length || importProblems.length > 0"
            @click="runImport"
          >
            {{ $t('admin.import.submit', { n: parsed.chapters.length }, parsed.chapters.length) }}
          </n-button>
        </div>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import {
  NAlert, NButton, NDataTable, NForm, NFormItem, NInput, NInputNumber, NModal, NSpace, NSpin, NSwitch, NTag,
  useDialog, useMessage,
} from 'naive-ui'
import type { DataTableColumns } from 'naive-ui'
import { h } from 'vue'
import type { ApiResponse } from '~/utils/api'
import type { ApiChapter, ApiChapterInput, ApiNovel } from '~/types/models'
import { MAX_IMPORT_CHAPTERS, parseChapterImport, type ImportedChapter } from '~/utils/chapterImport'

definePageMeta({ middleware: 'admin', layout: 'admin' })

const { t, locale } = useI18n()
const { dateTime } = useAdminLabels()
useHead({ title: () => t('admin.chapters.title') })

const route = useRoute()
const router = useRouter()
const message = useMessage()
const dialog = useDialog()

const novelId = computed(() => route.params.id as string)
const novelTitle = ref('')
const chapters = ref<ApiChapter[]>([])
const loading = ref(false)

const nextNumber = computed(() => chapters.value.reduce((max, c) => Math.max(max, c.chapter_number), 0) + 1)

function conflictMessage(error: unknown, fallback: string) {
  return statusOf(error) === 409 ? t('admin.chapters.numberTaken') : describeError(t, error, {}, fallback)
}

async function load() {
  loading.value = true
  try {
    const [list, novel] = await Promise.all([
      apiFetch<ApiResponse<ApiChapter[]>>(`/admin/novels/${novelId.value}/chapters`),
      novelTitle.value ? Promise.resolve(null) : apiFetch<ApiResponse<ApiNovel>>(`/admin/novels/${novelId.value}`),
    ])
    chapters.value = [...list.data].sort((a, b) => a.chapter_number - b.chapter_number)
    if (novel) novelTitle.value = novel.data.title
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('admin.chapters.loadFailed')))
  }
  finally {
    loading.value = false
  }
}

// ---------------------------------------------------------------- editor

const editorOpen = ref(false)
const editorLoading = ref(false)
const saving = ref(false)
const editing = reactive({
  id: '' as string,
  title: '',
  content: '',
  chapter_number: 1 as number | null,
  is_published: true,
  is_free: true,
})

function openCreate() {
  Object.assign(editing, { id: '', title: '', content: '', chapter_number: nextNumber.value, is_published: true, is_free: true })
  editorOpen.value = true
}

async function fetchChapter(id: string): Promise<ApiChapter> {
  const res = await apiFetch<ApiResponse<ApiChapter>>(`/admin/chapters/${id}`)
  return res.data
}

async function openEdit(row: ApiChapter) {
  Object.assign(editing, {
    id: row.id, title: row.title, content: '', chapter_number: row.chapter_number,
    is_published: !!row.is_published, is_free: row.is_free !== false,
  })
  editorOpen.value = true
  editorLoading.value = true
  try {
    const ch = await fetchChapter(row.id)
    editing.content = ch.content ?? ''
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('admin.chapters.loadContentFailed')))
    editorOpen.value = false
  }
  finally {
    editorLoading.value = false
  }
}

async function saveChapter() {
  if (!editing.title.trim() || !editing.content.trim() || !editing.chapter_number) {
    message.warning(t('admin.chapters.required'))
    return
  }
  const body: ApiChapterInput = {
    title: editing.title.trim(),
    content: editing.content,
    chapter_number: editing.chapter_number,
    is_published: editing.is_published,
    is_free: editing.is_free,
  }
  saving.value = true
  try {
    if (editing.id) {
      await apiFetch(`/admin/chapters/${editing.id}`, { method: 'PUT', body })
      message.success(t('admin.chapters.saved'))
    }
    else {
      await apiFetch(`/admin/novels/${novelId.value}/chapters`, { method: 'POST', body })
      message.success(t('admin.chapters.created'))
    }
    editorOpen.value = false
    await load()
  }
  catch (error) {
    message.error(conflictMessage(error, t('admin.chapters.saveFailed')))
  }
  finally {
    saving.value = false
  }
}

/** Flips is_published or is_free; the API replaces the whole chapter, so fetch its content first. */
async function toggleFlag(row: ApiChapter, flag: 'is_published' | 'is_free', value: boolean) {
  try {
    const ch = await fetchChapter(row.id)
    await apiFetch(`/admin/chapters/${row.id}`, {
      method: 'PUT',
      body: {
        title: ch.title,
        content: ch.content ?? '',
        chapter_number: ch.chapter_number,
        is_published: ch.is_published,
        is_free: ch.is_free,
        [flag]: value,
      } satisfies ApiChapterInput,
    })
    row[flag] = value
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('admin.chapters.updateFailed')))
  }
}

function confirmDelete(row: ApiChapter) {
  dialog.warning({
    title: t('admin.chapters.delete'),
    content: t('admin.chapters.confirmDelete', { n: row.chapter_number, title: row.title }),
    positiveText: t('common.delete'),
    negativeText: t('common.cancel'),
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/chapters/${row.id}`, { method: 'DELETE' })
        message.success(t('common.deleted'))
        await load()
      }
      catch (error) {
        message.error(describeError(t, error, {}, t('common.deleteFailed')))
      }
    },
  })
}

const columns = computed<DataTableColumns<ApiChapter>>(() => [
  { title: '#', key: 'chapter_number', width: 70 },
  { title: t('admin.columns.title'), key: 'title', minWidth: 200 },
  { title: t('profile.stats.words'), key: 'word_count', width: 80 },
  {
    title: t('admin.chapters.publish'),
    key: 'is_published',
    width: 80,
    render: row => h(NSwitch, {
      size: 'small',
      value: !!row.is_published,
      onUpdateValue: (v: boolean) => toggleFlag(row, 'is_published', v),
    }),
  },
  {
    title: t('admin.chapters.free'),
    key: 'is_free',
    width: 80,
    render: row => h(NSwitch, {
      size: 'small',
      value: row.is_free !== false,
      onUpdateValue: (v: boolean) => toggleFlag(row, 'is_free', v),
    }),
  },
  { title: t('admin.columns.updatedAt'), key: 'updated_at', width: 170, render: row => dateTime(row.updated_at) },
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

// ---------------------------------------------------------------- import

const importOpen = ref(false)
const importText = ref('')
const importPublished = ref(true)
const importFree = ref(true)
const importing = ref(false)

const parsed = computed(() => parseChapterImport(importText.value, {
  startNumber: nextNumber.value,
  is_published: importPublished.value,
  is_free: importFree.value,
}))

const importProblems = computed(() => {
  if (!importText.value.trim()) return []
  const existing = new Set(chapters.value.map(c => c.chapter_number))
  const clashes = parsed.value.chapters.filter(c => existing.has(c.chapter_number)).map(c => c.chapter_number)
  const errors = parsed.value.errors.map(e => t(e.key, e.params ?? {}))
  return clashes.length
    ? [...errors, t('admin.import.existingNumbers', { list: clashes.slice(0, 20).join(t('admin.import.listSeparator')) })]
    : errors
})

const previewColumns = computed<DataTableColumns<ImportedChapter>>(() => [
  { title: '#', key: 'chapter_number', width: 70 },
  { title: t('admin.columns.title'), key: 'title' },
  { title: t('profile.stats.words'), key: 'content', width: 90, render: row => row.content.length },
  {
    title: t('admin.columns.status'),
    key: 'is_published',
    width: 90,
    render: row => h(NTag, { size: 'small', type: row.is_published ? 'success' : 'default' }, () => row.is_published ? t('admin.chapters.publish') : t('admin.chapters.draft')),
  },
])

function openImport() {
  importText.value = ''
  importOpen.value = true
}

async function runImport() {
  importing.value = true
  try {
    const res = await apiFetch<ApiResponse<{ imported: number }>>(`/admin/novels/${novelId.value}/chapters/batch`, {
      method: 'POST',
      body: parsed.value.chapters,
    })
    message.success(t('admin.import.done', { n: res.data.imported }, res.data.imported))
    importOpen.value = false
    await load()
  }
  catch (error) {
    message.error(conflictMessage(error, t('admin.import.failed')))
  }
  finally {
    importing.value = false
  }
}

onMounted(load)
</script>
