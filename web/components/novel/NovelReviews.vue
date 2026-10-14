<template>
  <n-card data-testid="novel-reviews">
    <template #header>
      <div class="flex items-center gap-3">
        <span>書評</span>
        <span class="text-sm text-gray-400 font-normal">共 {{ pagination.total }} 則</span>
      </div>
    </template>
    <template #header-extra>
      <n-radio-group v-model:value="sort" size="small">
        <n-radio-button value="latest">最新</n-radio-button>
        <n-radio-button value="popular">最熱</n-radio-button>
      </n-radio-group>
    </template>

    <div v-if="!isLoggedIn" class="mb-4 text-sm text-gray-500">
      <NuxtLink :to="`/login?redirect=${encodeURIComponent(route.fullPath)}`" class="text-primary">登入</NuxtLink>後即可撰寫書評
    </div>
    <div v-else-if="!myReview && !editorOpen" class="mb-4">
      <n-button type="primary" secondary data-testid="review-write" @click="openEditor()">撰寫書評</n-button>
    </div>

    <div v-if="editorOpen" class="mb-6 p-4 rounded border border-gray-200 space-y-3" data-testid="review-editor">
      <div class="flex items-center gap-3">
        <span class="text-sm">評分</span>
        <n-rate v-model:value="form.rating" allow-half data-testid="review-rating" />
        <span class="text-sm text-gray-500">{{ form.rating.toFixed(1) }}</span>
      </div>
      <n-input v-model:value="form.title" maxlength="200" placeholder="標題" data-testid="review-title" />
      <n-input
        v-model:value="form.content"
        type="textarea"
        :rows="4"
        maxlength="10000"
        show-count
        placeholder="分享你對這本書的看法"
        data-testid="review-content"
      />
      <div class="flex justify-end gap-2">
        <n-button :disabled="saving" @click="editorOpen = false">取消</n-button>
        <n-button type="primary" :loading="saving" :disabled="!canSave" data-testid="review-save" @click="save">
          {{ editingId ? '更新書評' : '發表書評' }}
        </n-button>
      </div>
    </div>

    <n-spin :show="loading">
      <div class="space-y-4">
        <div v-for="r in items" :key="r.id" class="border-b border-gray-100 pb-4 last:border-0" data-testid="review-item">
          <div class="flex items-center gap-3">
            <n-avatar :src="r.user?.avatar_url || undefined" :size="32" round>
              <template v-if="!r.user?.avatar_url">{{ (r.user?.nickname || r.user?.username || '讀').slice(0, 1) }}</template>
            </n-avatar>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-sm font-medium">{{ r.user?.nickname || r.user?.username || '讀者' }}</span>
                <n-rate :value="r.rating" readonly allow-half size="small" />
                <n-tag v-if="r.user_id === userId" size="tiny" type="info" :bordered="false">我的書評</n-tag>
              </div>
              <div class="text-xs text-gray-400">{{ r.created_at ? formatRelativeTime(r.created_at) : '' }}</div>
            </div>
          </div>
          <div class="mt-2 font-semibold" data-testid="review-item-title">{{ r.title }}</div>
          <div class="mt-1 text-sm text-gray-700 whitespace-pre-wrap break-words">{{ r.content }}</div>
          <div class="flex items-center gap-3 mt-2">
            <n-button text size="small" :type="r.liked_by_me ? 'primary' : 'default'" data-testid="review-like" @click="like(r)">
              {{ r.liked_by_me ? '已讚' : '讚' }} {{ r.like_count || '' }}
            </n-button>
            <template v-if="r.user_id === userId">
              <n-button text size="small" data-testid="review-edit" @click="openEditor(r)">編輯</n-button>
              <n-popconfirm @positive-click="remove(r)">
                <template #trigger>
                  <n-button text size="small" type="error" data-testid="review-delete">刪除</n-button>
                </template>
                確定刪除你的書評？
              </n-popconfirm>
            </template>
            <n-button v-else-if="isLoggedIn" text size="small" data-testid="review-report" @click="openReport(r.id)">檢舉</n-button>
          </div>
        </div>
        <div v-if="!loading && items.length === 0" class="text-center text-sm text-gray-400 py-6">
          還沒有書評
        </div>
      </div>
    </n-spin>

    <div v-if="pagination.total_pages > 1" class="flex justify-center mt-4">
      <n-pagination :page="pagination.page" :page-count="pagination.total_pages" @update:page="load" />
    </div>

    <ReportDialog v-model:show="reportOpen" target-type="review" :target-id="reportTarget" />
  </n-card>
</template>

<script setup lang="ts">
import {
  NCard, NRadioGroup, NRadioButton, NButton, NRate, NInput, NSpin, NAvatar, NTag, NPopconfirm, NPagination, useMessage,
} from 'naive-ui'
import type { ApiReview } from '~/types/models'
import { formatRelativeTime } from '~/utils/format'

const props = defineProps<{ novelId: string }>()
const emit = defineEmits<{ changed: [] }>()

const route = useRoute()
const message = useMessage()
const authStore = useAuthStore()
const isLoggedIn = computed(() => authStore.isLoggedIn)
const userId = computed(() => authStore.user?.id)

const { items, pagination, sort, loading, myReview, load, create, update, remove: removeReview, toggleLike } = useReviews(() => props.novelId)

const editorOpen = ref(false)
const editingId = ref<string | null>(null)
const saving = ref(false)
const form = reactive({ rating: 5, title: '', content: '' })
const canSave = computed(() => form.rating >= 0.5 && form.title.trim() && form.content.trim())

const reportOpen = ref(false)
const reportTarget = ref<string | null>(null)

function openEditor(review?: ApiReview) {
  editingId.value = review?.id ?? null
  form.rating = review?.rating ?? 5
  form.title = review?.title ?? ''
  form.content = review?.content ?? ''
  editorOpen.value = true
}

async function save() {
  saving.value = true
  const input = { rating: form.rating, title: form.title.trim(), content: form.content.trim() }
  try {
    if (editingId.value) {
      await update(editingId.value, input)
      message.success('書評已更新')
    }
    else {
      await create(input)
      message.success('書評已發表')
    }
    editorOpen.value = false
    emit('changed')
  }
  catch (e) {
    if (statusOf(e) === 409) {
      message.warning('你已經評論過這本書，可以編輯原本的書評')
      sort.value = 'latest'
      await load()
      editorOpen.value = false
    }
    else {
      message.error(describeError(e, { 400: '請填寫評分、標題與內容', 404: '找不到這本小說' }, '發表失敗，請稍後再試'))
    }
  }
  finally {
    saving.value = false
  }
}

async function remove(review: ApiReview) {
  try {
    await removeReview(review.id)
    message.success('書評已刪除')
    emit('changed')
  }
  catch (e) {
    message.error(describeError(e, {}, '刪除失敗'))
  }
}

async function like(review: ApiReview) {
  if (!isLoggedIn.value) {
    message.info('請先登入')
    return
  }
  try {
    await toggleLike(review)
  }
  catch (e) {
    message.error(describeError(e, {}, '操作失敗'))
  }
}

function openReport(id: string) {
  reportTarget.value = id
  reportOpen.value = true
}

watch(sort, () => load())
onMounted(() => load())
</script>
