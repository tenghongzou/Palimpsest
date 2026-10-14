<template>
  <div class="space-y-4">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <n-button text @click="router.push(`/admin/novels/${novelId}`)">← 返回小說</n-button>
        <h1 class="text-xl font-bold">章節管理<span v-if="novelTitle" class="text-gray-500 font-normal">：{{ novelTitle }}</span></h1>
      </div>
      <div class="flex gap-2">
        <n-button @click="openImport">批次匯入</n-button>
        <n-button type="primary" @click="openCreate">新增章節</n-button>
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
      :title="editing.id ? '編輯章節' : '新增章節'"
      class="max-w-3xl"
      :mask-closable="false"
    >
      <n-spin :show="editorLoading">
        <n-form label-placement="left" label-width="80">
          <n-form-item label="章節編號">
            <n-input-number v-model:value="editing.chapter_number" :min="1" placeholder="章節編號" />
          </n-form-item>
          <n-form-item label="標題">
            <n-input v-model:value="editing.title" placeholder="章節標題" maxlength="200" />
          </n-form-item>
          <n-form-item label="內容">
            <n-input
              v-model:value="editing.content"
              type="textarea"
              placeholder="章節內容，段落之間以換行分隔"
              :autosize="{ minRows: 10, maxRows: 24 }"
            />
          </n-form-item>
          <n-form-item label="發佈">
            <n-switch v-model:value="editing.is_published" />
            <span class="ml-6 mr-2">免費</span>
            <n-switch v-model:value="editing.is_free" />
          </n-form-item>
        </n-form>
      </n-spin>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="editorOpen = false">取消</n-button>
          <n-button type="primary" :loading="saving" @click="saveChapter">儲存章節</n-button>
        </div>
      </template>
    </n-modal>

    <!-- Batch import -->
    <n-modal v-model:show="importOpen" preset="card" title="批次匯入章節" class="max-w-4xl" :mask-closable="false">
      <div class="space-y-3">
        <p class="text-sm text-gray-500">
          貼上全文，以「第一章 標題」、「第12章」或「Chapter 3」等標題分章；或貼上 JSON 陣列
          <code>[{"title": "...", "content": "...", "chapter_number": 1}]</code>。一次最多 {{ MAX_IMPORT_CHAPTERS }} 章。
        </p>
        <n-input
          v-model:value="importText"
          type="textarea"
          placeholder="在此貼上章節內容"
          :autosize="{ minRows: 8, maxRows: 16 }"
          data-testid="import-text"
        />
        <div class="flex items-center gap-6 text-sm">
          <span class="flex items-center gap-2">發佈 <n-switch v-model:value="importPublished" /></span>
          <span class="flex items-center gap-2">免費 <n-switch v-model:value="importFree" /></span>
          <span class="text-gray-500">JSON 未指定編號時從 {{ nextNumber }} 開始</span>
        </div>
        <n-alert v-if="importProblems.length" type="error" :show-icon="false">
          <div v-for="(e, i) in importProblems.slice(0, 10)" :key="i">{{ e }}</div>
          <div v-if="importProblems.length > 10">……還有 {{ importProblems.length - 10 }} 個問題</div>
        </n-alert>
        <div v-if="parsed.chapters.length" class="text-sm">
          預覽：共 {{ parsed.chapters.length }} 章
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
          <n-button @click="importOpen = false">取消</n-button>
          <n-button
            type="primary"
            :loading="importing"
            :disabled="!parsed.chapters.length || importProblems.length > 0"
            @click="runImport"
          >
            匯入 {{ parsed.chapters.length }} 章
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
useHead({ title: '章節管理 — Palimpsest' })

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
  return statusOf(error) === 409 ? '章節編號已存在，請改用其他編號' : describeError(error, {}, fallback)
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
    message.error(describeError(error, {}, '載入章節失敗'))
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
    message.error(describeError(error, {}, '載入章節內容失敗'))
    editorOpen.value = false
  }
  finally {
    editorLoading.value = false
  }
}

async function saveChapter() {
  if (!editing.title.trim() || !editing.content.trim() || !editing.chapter_number) {
    message.warning('請填寫章節編號、標題與內容')
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
      message.success('章節已儲存')
    }
    else {
      await apiFetch(`/admin/novels/${novelId.value}/chapters`, { method: 'POST', body })
      message.success('章節已新增')
    }
    editorOpen.value = false
    await load()
  }
  catch (error) {
    message.error(conflictMessage(error, '儲存章節失敗'))
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
    message.error(describeError(error, {}, '更新失敗'))
  }
}

function confirmDelete(row: ApiChapter) {
  dialog.warning({
    title: '刪除章節',
    content: `確定要刪除第 ${row.chapter_number} 章「${row.title}」嗎？`,
    positiveText: '刪除',
    negativeText: '取消',
    onPositiveClick: async () => {
      try {
        await apiFetch(`/admin/chapters/${row.id}`, { method: 'DELETE' })
        message.success('已刪除')
        await load()
      }
      catch (error) {
        message.error(describeError(error, {}, '刪除失敗'))
      }
    },
  })
}

const columns: DataTableColumns<ApiChapter> = [
  { title: '#', key: 'chapter_number', width: 70 },
  { title: '標題', key: 'title', minWidth: 200 },
  { title: '字數', key: 'word_count', width: 80 },
  {
    title: '發佈',
    key: 'is_published',
    width: 80,
    render: row => h(NSwitch, {
      size: 'small',
      value: !!row.is_published,
      onUpdateValue: (v: boolean) => toggleFlag(row, 'is_published', v),
    }),
  },
  {
    title: '免費',
    key: 'is_free',
    width: 80,
    render: row => h(NSwitch, {
      size: 'small',
      value: row.is_free !== false,
      onUpdateValue: (v: boolean) => toggleFlag(row, 'is_free', v),
    }),
  },
  { title: '更新時間', key: 'updated_at', width: 170, render: row => adminDateTime(row.updated_at) },
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
  return clashes.length
    ? [...parsed.value.errors, `以下章節編號已存在：${clashes.slice(0, 20).join('、')}`]
    : parsed.value.errors
})

const previewColumns: DataTableColumns<ImportedChapter> = [
  { title: '#', key: 'chapter_number', width: 70 },
  { title: '標題', key: 'title' },
  { title: '字數', key: 'content', width: 90, render: row => row.content.length },
  {
    title: '狀態',
    key: 'is_published',
    width: 90,
    render: row => h(NTag, { size: 'small', type: row.is_published ? 'success' : 'default' }, () => row.is_published ? '發佈' : '草稿'),
  },
]

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
    message.success(`已匯入 ${res.data.imported} 章`)
    importOpen.value = false
    await load()
  }
  catch (error) {
    message.error(conflictMessage(error, '匯入失敗'))
  }
  finally {
    importing.value = false
  }
}

onMounted(load)
</script>
