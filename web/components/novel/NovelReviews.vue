<template>
  <n-card data-testid="novel-reviews">
    <template #header>
      <div class="flex items-center gap-3">
        <span>{{ $t('reviews.title') }}</span>
        <span class="text-sm text-gray-400 font-normal">{{ $t('reviews.total', { n: pagination.total }, pagination.total) }}</span>
      </div>
    </template>
    <template #header-extra>
      <n-radio-group v-model:value="sort" size="small">
        <n-radio-button value="latest">{{ $t('comments.sortLatest') }}</n-radio-button>
        <n-radio-button value="popular">{{ $t('comments.sortPopular') }}</n-radio-button>
      </n-radio-group>
    </template>

    <div v-if="!isLoggedIn" class="mb-4 text-sm text-gray-500">
      <i18n-t keypath="reviews.loginToWrite" tag="span" scope="global">
        <template #login>
          <NuxtLink :to="`/login?redirect=${encodeURIComponent(route.fullPath)}`" class="text-primary">{{ $t('common.login') }}</NuxtLink>
        </template>
      </i18n-t>
    </div>
    <div v-else-if="!myReview && !editorOpen" class="mb-4">
      <n-button type="primary" secondary data-testid="review-write" @click="openEditor()">{{ $t('reviews.write') }}</n-button>
    </div>

    <div v-if="editorOpen" class="mb-6 p-4 rounded border border-gray-200 space-y-3" data-testid="review-editor">
      <div class="flex items-center gap-3">
        <span class="text-sm">{{ $t('reviews.rating') }}</span>
        <n-rate v-model:value="form.rating" allow-half data-testid="review-rating" />
        <span class="text-sm text-gray-500">{{ form.rating.toFixed(1) }}</span>
      </div>
      <n-input v-model:value="form.title" maxlength="200" :placeholder="$t('reviews.titlePlaceholder')" data-testid="review-title" />
      <n-input
        v-model:value="form.content"
        type="textarea"
        :rows="4"
        maxlength="10000"
        show-count
        :placeholder="$t('reviews.contentPlaceholder')"
        data-testid="review-content"
      />
      <div class="flex justify-end gap-2">
        <n-button :disabled="saving" @click="editorOpen = false">{{ $t('common.cancel') }}</n-button>
        <n-button type="primary" :loading="saving" :disabled="!canSave" data-testid="review-save" @click="save">
          {{ editingId ? $t('reviews.update') : $t('reviews.publish') }}
        </n-button>
      </div>
    </div>

    <n-spin :show="loading">
      <div class="space-y-4">
        <div v-for="r in items" :key="r.id" class="border-b border-gray-100 pb-4 last:border-0" data-testid="review-item">
          <div class="flex items-center gap-3">
            <n-avatar :src="r.user?.avatar_url || undefined" :size="32" round>
              <template v-if="!r.user?.avatar_url">{{ (r.user?.nickname || r.user?.username || $t('comments.anonymous')).slice(0, 1) }}</template>
            </n-avatar>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-sm font-medium">{{ r.user?.nickname || r.user?.username || $t('comments.anonymous') }}</span>
                <n-rate :value="r.rating" readonly allow-half size="small" />
                <n-tag v-if="r.user_id === userId" size="tiny" type="info" :bordered="false">{{ $t('reviews.mine') }}</n-tag>
              </div>
              <div class="text-xs text-gray-400">{{ r.created_at ? formatRelativeTime(r.created_at) : '' }}</div>
            </div>
          </div>
          <div class="mt-2 font-semibold" data-testid="review-item-title">{{ r.title }}</div>
          <div class="mt-1 text-sm text-gray-700 whitespace-pre-wrap break-words">{{ r.content }}</div>
          <div class="flex items-center gap-3 mt-2">
            <n-button text size="small" :type="r.liked_by_me ? 'primary' : 'default'" data-testid="review-like" @click="like(r)">
              {{ r.liked_by_me ? $t('community.liked') : $t('community.like') }} {{ r.like_count || '' }}
            </n-button>
            <template v-if="r.user_id === userId">
              <n-button text size="small" data-testid="review-edit" @click="openEditor(r)">{{ $t('common.edit') }}</n-button>
              <n-popconfirm @positive-click="remove(r)">
                <template #trigger>
                  <n-button text size="small" type="error" data-testid="review-delete">{{ $t('common.delete') }}</n-button>
                </template>
                {{ $t('reviews.confirmDelete') }}
              </n-popconfirm>
            </template>
            <n-button v-else-if="isLoggedIn" text size="small" data-testid="review-report" @click="openReport(r.id)">{{ $t('community.report.action') }}</n-button>
          </div>
        </div>
        <div v-if="!loading && items.length === 0" class="text-center text-sm text-gray-400 py-6">
          {{ $t('reviews.empty') }}
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

const props = defineProps<{ novelId: string }>()
const emit = defineEmits<{ changed: [] }>()

const { t, formatRelativeTime } = useFormat()
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
      message.success(t('reviews.updated'))
    }
    else {
      await create(input)
      message.success(t('reviews.published'))
    }
    editorOpen.value = false
    emit('changed')
  }
  catch (e) {
    if (statusOf(e) === 409) {
      message.warning(t('reviews.alreadyReviewed'))
      sort.value = 'latest'
      await load()
      editorOpen.value = false
    }
    else {
      message.error(describeError(t, e, { 400: t('reviews.invalid'), 404: t('novel.notFound') }, t('reviews.publishFailed')))
    }
  }
  finally {
    saving.value = false
  }
}

async function remove(review: ApiReview) {
  try {
    await removeReview(review.id)
    message.success(t('reviews.deleted'))
    emit('changed')
  }
  catch (e) {
    message.error(describeError(t, e, {}, t('common.deleteFailed')))
  }
}

async function like(review: ApiReview) {
  if (!isLoggedIn.value) {
    message.info(t('auth.loginFirst'))
    return
  }
  try {
    await toggleLike(review)
  }
  catch (e) {
    message.error(describeError(t, e, {}, t('common.operationFailed')))
  }
}

function openReport(id: string) {
  reportTarget.value = id
  reportOpen.value = true
}

watch(sort, () => load())
onMounted(() => load())
</script>
