<template>
  <div class="space-y-4 max-w-3xl">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <n-button text @click="router.push('/admin/novels')">{{ $t('admin.novels.backToList') }}</n-button>
        <h1 class="text-xl font-bold">{{ isNew ? $t('admin.novels.create') : $t('admin.novels.edit') }}</h1>
        <n-tag v-if="novel" size="small" :type="novel.is_published ? 'success' : 'default'">
          {{ novel.is_published ? $t('admin.novels.published') : $t('admin.novels.unpublished') }}
        </n-tag>
      </div>
      <div v-if="novel" class="flex gap-2">
        <n-button @click="router.push(`/admin/novels/${novel.id}/chapters`)">{{ $t('admin.novels.manageChapters') }}</n-button>
        <n-button :type="novel.is_published ? 'warning' : 'primary'" :loading="publishing" @click="togglePublish">
          {{ novel.is_published ? $t('admin.novels.unpublish') : $t('admin.novels.publish') }}
        </n-button>
      </div>
    </div>

    <n-spin :show="loading">
      <n-card>
        <n-form ref="formRef" :model="form" :rules="rules" label-placement="left" :label-width="locale === 'en' ? 120 : 90">
          <n-form-item :label="$t('admin.novels.title')" path="title">
            <n-input v-model:value="form.title" :placeholder="$t('admin.novels.title')" maxlength="200" />
          </n-form-item>
          <n-form-item :label="$t('admin.novels.author')" path="author_name">
            <n-input v-model:value="form.author_name" :placeholder="$t('admin.novels.authorPlaceholder')" maxlength="100" />
          </n-form-item>
          <n-form-item :label="$t('novel.synopsis')" path="description">
            <n-input v-model:value="form.description" type="textarea" :placeholder="$t('admin.novels.synopsisPlaceholder')" :autosize="{ minRows: 3, maxRows: 10 }" />
          </n-form-item>
          <n-form-item :label="$t('admin.novels.serialStatus')" path="status">
            <n-select v-model:value="form.status" :options="novelStatusOptions" />
          </n-form-item>
          <n-form-item :label="$t('admin.novels.language')" path="language">
            <n-select v-model:value="form.language" :options="LANGUAGE_OPTIONS" />
          </n-form-item>
          <n-form-item :label="$t('admin.novels.featuredOnHome')" path="is_featured">
            <n-switch v-model:value="form.is_featured" />
          </n-form-item>
          <n-form-item :label="$t('admin.novels.cover')" path="cover_url">
            <AdminImageUpload v-model="form.cover_url" kind="covers" />
          </n-form-item>
          <n-form-item :label="$t('category.title')" path="category_ids">
            <n-select
              v-model:value="form.category_ids"
              :options="categoryOptions"
              multiple
              filterable
              :placeholder="$t('admin.novels.categoriesPlaceholder')"
              data-testid="novel-categories"
            />
          </n-form-item>
          <n-form-item :label="$t('admin.novels.tags')" path="tags">
            <n-dynamic-tags v-model:value="form.tags" :max="20" />
          </n-form-item>
          <div class="flex justify-end gap-2">
            <n-button @click="router.push('/admin/novels')">{{ $t('common.cancel') }}</n-button>
            <n-button type="primary" :loading="saving" @click="save">{{ $t('common.save') }}</n-button>
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

const { t, locale } = useI18n()
const { novelStatusOptions } = useAdminLabels()
const route = useRoute()
const router = useRouter()
const message = useMessage()

const novelId = computed(() => route.params.id as string)
const isNew = computed(() => novelId.value === 'new')
useHead({ title: () => (isNew.value ? t('admin.novels.create') : t('admin.novels.edit')) })

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

const rules = computed<FormRules>(() => ({
  title: { required: true, message: t('admin.novels.titleRequired'), trigger: 'blur' },
  author_name: { required: true, message: t('admin.novels.authorRequired'), trigger: 'blur' },
}))

// Children are listed right after their parent as "Parent / Child".
const categoryOptions = computed(() => {
  const parents = categories.value.filter(c => !c.parent_id)
  const options: { label: string, value: number }[] = []
  for (const p of parents) {
    options.push({ label: p.is_active === false ? t('admin.novels.disabledCategory', { name: p.name }) : p.name, value: p.id })
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
  form.tags = (n.tags ?? []).map(tag => tag.name)
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
    message.error(describeError(t, error, {}, t('common.loadFailed')))
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
    tags: form.tags.map(tag => tag.trim()).filter(Boolean),
  }
  saving.value = true
  try {
    if (isNew.value) {
      const res = await apiFetch<ApiResponse<ApiNovel>>('/admin/novels', { method: 'POST', body })
      message.success(t('admin.novels.created'))
      fillForm(res.data)
      await router.replace(`/admin/novels/${res.data.id}`)
    }
    else {
      const res = await apiFetch<ApiResponse<ApiNovel>>(`/admin/novels/${novelId.value}`, { method: 'PUT', body })
      fillForm(res.data)
      message.success(t('common.saved'))
    }
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('common.saveFailed')))
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
    message.success(publish ? t('admin.novels.published') : t('admin.novels.unpublishedToast'))
  }
  catch (error) {
    message.error(describeError(t, error, {}, t('common.operationFailed')))
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
