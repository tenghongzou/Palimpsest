<template>
  <div class="space-y-4 max-w-3xl">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <n-button text @click="router.push('/admin/novels')">← 返回列表</n-button>
        <h1 class="text-xl font-bold">{{ isNew ? '新增小說' : '編輯小說' }}</h1>
        <n-tag v-if="novel" size="small" :type="novel.is_published ? 'success' : 'default'">
          {{ novel.is_published ? '已上架' : '未上架' }}
        </n-tag>
      </div>
      <div v-if="novel" class="flex gap-2">
        <n-button @click="router.push(`/admin/novels/${novel.id}/chapters`)">管理章節</n-button>
        <n-button :type="novel.is_published ? 'warning' : 'primary'" :loading="publishing" @click="togglePublish">
          {{ novel.is_published ? '下架' : '上架' }}
        </n-button>
      </div>
    </div>

    <n-spin :show="loading">
      <n-card>
        <n-form ref="formRef" :model="form" :rules="rules" label-placement="left" label-width="90">
          <n-form-item label="書名" path="title">
            <n-input v-model:value="form.title" placeholder="書名" maxlength="200" />
          </n-form-item>
          <n-form-item label="作者" path="author_name">
            <n-input v-model:value="form.author_name" placeholder="作者名稱" maxlength="100" />
          </n-form-item>
          <n-form-item label="簡介" path="description">
            <n-input v-model:value="form.description" type="textarea" placeholder="小說簡介" :autosize="{ minRows: 3, maxRows: 10 }" />
          </n-form-item>
          <n-form-item label="連載狀態" path="status">
            <n-select v-model:value="form.status" :options="NOVEL_STATUS_OPTIONS" />
          </n-form-item>
          <n-form-item label="語言" path="language">
            <n-select v-model:value="form.language" :options="LANGUAGE_OPTIONS" />
          </n-form-item>
          <n-form-item label="首頁推薦" path="is_featured">
            <n-switch v-model:value="form.is_featured" />
          </n-form-item>
          <n-form-item label="封面" path="cover_url">
            <AdminImageUpload v-model="form.cover_url" kind="covers" />
          </n-form-item>
          <n-form-item label="分類" path="category_ids">
            <n-select
              v-model:value="form.category_ids"
              :options="categoryOptions"
              multiple
              filterable
              placeholder="選擇分類"
              data-testid="novel-categories"
            />
          </n-form-item>
          <n-form-item label="標籤" path="tags">
            <n-dynamic-tags v-model:value="form.tags" :max="20" />
          </n-form-item>
          <div class="flex justify-end gap-2">
            <n-button @click="router.push('/admin/novels')">取消</n-button>
            <n-button type="primary" :loading="saving" @click="save">儲存</n-button>
          </div>
        </n-form>
      </n-card>
    </n-spin>
  </div>
</template>

<script setup lang="ts">
import {
  NButton, NCard, NDynamicTags, NForm, NFormItem, NInput, NSelect, NSpin, NSwitch, NTag, useMessage,
} from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'
import type { ApiCategory, ApiNovel, ApiNovelInput } from '~/types/models'

definePageMeta({ middleware: 'admin', layout: 'admin' })

const route = useRoute()
const router = useRouter()
const message = useMessage()

const novelId = computed(() => route.params.id as string)
const isNew = computed(() => novelId.value === 'new')
useHead({ title: computed(() => `${isNew.value ? '新增' : '編輯'}小說 — Palimpsest`) })

const novel = ref<ApiNovel | null>(null)
const categories = ref<ApiCategory[]>([])
const loading = ref(false)
const saving = ref(false)
const publishing = ref(false)
const formRef = ref<FormInst | null>(null)

const form = reactive({
  title: '',
  author_name: '',
  description: '',
  status: 'ongoing' as NonNullable<ApiNovelInput['status']>,
  language: 'zh-TW' as NonNullable<ApiNovelInput['language']>,
  is_featured: false,
  cover_url: '',
  category_ids: [] as number[],
  tags: [] as string[],
})

const rules: FormRules = {
  title: { required: true, message: '請輸入書名', trigger: 'blur' },
  author_name: { required: true, message: '請輸入作者', trigger: 'blur' },
}

// Children are listed right after their parent as "父分類 / 子分類".
const categoryOptions = computed(() => {
  const parents = categories.value.filter(c => !c.parent_id)
  const options: { label: string, value: number }[] = []
  for (const p of parents) {
    options.push({ label: p.is_active === false ? `${p.name}（停用）` : p.name, value: p.id })
    for (const c of categories.value.filter(x => x.parent_id === p.id)) {
      options.push({ label: `${p.name} / ${c.name}`, value: c.id })
    }
  }
  // Orphans (parent missing) still need to be selectable.
  for (const c of categories.value) {
    if (c.parent_id && !parents.some(p => p.id === c.parent_id)) options.push({ label: c.name, value: c.id })
  }
  return options
})

function fillForm(n: ApiNovel) {
  novel.value = n
  form.title = n.title
  form.author_name = n.author_name
  form.description = n.description ?? ''
  form.status = n.status
  form.language = n.language
  form.is_featured = !!n.is_featured
  form.cover_url = n.cover_url ?? ''
  form.category_ids = (n.categories ?? []).map(c => c.id)
  form.tags = (n.tags ?? []).map(t => t.name)
}

async function load() {
  loading.value = true
  try {
    const [cats, n] = await Promise.all([
      apiFetch<ApiResponse<ApiCategory[]>>('/admin/categories'),
      isNew.value ? Promise.resolve(null) : apiFetch<ApiResponse<ApiNovel>>(`/admin/novels/${novelId.value}`),
    ])
    categories.value = cats.data
    if (n) fillForm(n.data)
  }
  catch (error) {
    message.error(describeError(error, {}, '載入失敗'))
  }
  finally {
    loading.value = false
  }
}

async function save() {
  try {
    await formRef.value?.validate()
  }
  catch {
    return
  }
  const body: ApiNovelInput = {
    title: form.title.trim(),
    author_name: form.author_name.trim(),
    description: form.description,
    status: form.status,
    language: form.language,
    is_featured: form.is_featured,
    cover_url: form.cover_url.trim(),
    category_ids: form.category_ids,
    tags: form.tags.map(t => t.trim()).filter(Boolean),
  }
  saving.value = true
  try {
    if (isNew.value) {
      const res = await apiFetch<ApiResponse<ApiNovel>>('/admin/novels', { method: 'POST', body })
      message.success('已建立小說')
      fillForm(res.data)
      await router.replace(`/admin/novels/${res.data.id}`)
    }
    else {
      const res = await apiFetch<ApiResponse<ApiNovel>>(`/admin/novels/${novelId.value}`, { method: 'PUT', body })
      fillForm(res.data)
      message.success('已儲存')
    }
  }
  catch (error) {
    message.error(describeError(error, {}, '儲存失敗'))
  }
  finally {
    saving.value = false
  }
}

async function togglePublish() {
  if (!novel.value) return
  const publish = !novel.value.is_published
  publishing.value = true
  try {
    const res = await apiFetch<ApiResponse<ApiNovel>>(`/admin/novels/${novel.value.id}/publish`, {
      method: 'POST',
      body: { is_published: publish },
    })
    novel.value = { ...novel.value, ...res.data }
    message.success(publish ? '已上架' : '已下架')
  }
  catch (error) {
    message.error(describeError(error, {}, '操作失敗'))
  }
  finally {
    publishing.value = false
  }
}

watch(novelId, (id, old) => {
  // Creating a novel replaces /new with its id; the form already holds it.
  if (old === 'new' && novel.value?.id === id) return
  void load()
})
onMounted(load)
</script>
