<template>
  <div class="space-y-4" data-testid="chapter-comments">
    <div class="flex items-center justify-between">
      <span class="text-sm text-gray-500">共 {{ pagination.total }} 則留言</span>
      <n-radio-group v-model:value="sort" size="small">
        <n-radio-button value="latest">最新</n-radio-button>
        <n-radio-button value="popular">最熱</n-radio-button>
      </n-radio-group>
    </div>

    <div v-if="isLoggedIn" class="space-y-2">
      <div v-if="replyTo" class="text-xs text-gray-500 flex items-center gap-2">
        回覆 {{ replyTo.user?.nickname || replyTo.user?.username || '讀者' }}
        <n-button text size="tiny" @click="replyTo = null">取消</n-button>
      </div>
      <n-input
        ref="inputRef"
        v-model:value="draft"
        type="textarea"
        :rows="3"
        maxlength="2000"
        show-count
        :placeholder="replyTo ? '寫下你的回覆…' : '分享你對這一章的想法…'"
        data-testid="comment-input"
      />
      <div class="flex items-center justify-between">
        <n-checkbox v-if="!replyTo" v-model:checked="attachParagraph">
          針對目前段落（第 {{ currentParagraph + 1 }} 段）
        </n-checkbox>
        <span v-else />
        <n-button type="primary" size="small" :loading="posting" :disabled="!draft.trim()" data-testid="comment-submit" @click="post">
          {{ replyTo ? '回覆' : '發表留言' }}
        </n-button>
      </div>
    </div>
    <n-alert v-else type="info" :show-icon="false">
      <NuxtLink :to="`/login?redirect=${encodeURIComponent(route.fullPath)}`" class="text-primary">登入</NuxtLink>後即可留言
    </n-alert>

    <n-spin :show="loading">
      <div class="space-y-4">
        <div v-for="c in items" :key="c.id" class="border-b border-gray-100 pb-3" data-testid="comment-item">
          <CommentEntry
            :comment="c"
            :can-delete="canDelete(c)"
            @like="like(c)"
            @reply="startReply(c)"
            @remove="remove(c)"
            @report="openReport(c)"
          />
          <div v-if="c.replies?.length" class="ml-10 mt-2 space-y-2 border-l-2 border-gray-100 pl-3">
            <CommentEntry
              v-for="r in c.replies"
              :key="r.id"
              :comment="r"
              :can-delete="canDelete(r)"
              compact
              @like="like(r)"
              @reply="startReply(c)"
              @remove="remove(r)"
              @report="openReport(r)"
            />
          </div>
        </div>
        <div v-if="!loading && items.length === 0" class="text-center text-sm text-gray-400 py-6">
          還沒有留言，來搶頭香吧
        </div>
      </div>
    </n-spin>

    <div v-if="pagination.total_pages > 1" class="flex justify-center">
      <n-pagination :page="pagination.page" :page-count="pagination.total_pages" size="small" @update:page="load" />
    </div>

    <ReportDialog v-model:show="reportOpen" target-type="comment" :target-id="reportTarget" />
  </div>
</template>

<script setup lang="ts">
import { NRadioGroup, NRadioButton, NInput, NButton, NCheckbox, NAlert, NSpin, NPagination, useMessage } from 'naive-ui'
import type { ApiComment } from '~/types/models'

const props = defineProps<{
  chapterId: string
  currentParagraph: number
}>()

const route = useRoute()
const message = useMessage()
const authStore = useAuthStore()
const isLoggedIn = computed(() => authStore.isLoggedIn)

const { items, pagination, sort, loading, load, create, remove: removeComment, toggleLike } = useComments(() => props.chapterId)

const draft = ref('')
const posting = ref(false)
const attachParagraph = ref(false)
const replyTo = ref<ApiComment | null>(null)
const inputRef = ref<{ focus: () => void } | null>(null)
const reportOpen = ref(false)
const reportTarget = ref<string | null>(null)

function canDelete(c: ApiComment) {
  return c.user_id === authStore.user?.id || authStore.isAdmin
}

function startReply(c: ApiComment) {
  if (!isLoggedIn.value) {
    message.info('請先登入')
    return
  }
  replyTo.value = c
  nextTick(() => inputRef.value?.focus())
}

async function post() {
  if (!draft.value.trim()) return
  posting.value = true
  try {
    await create({
      content: draft.value,
      ...(replyTo.value ? { parent_id: replyTo.value.id } : {}),
      ...(!replyTo.value && attachParagraph.value ? { paragraph_index: props.currentParagraph } : {}),
    })
    draft.value = ''
    replyTo.value = null
    attachParagraph.value = false
    message.success('留言已發表')
  }
  catch (e) {
    message.error(describeError(e, { 400: '留言內容不正確（最多 2000 字）', 404: '找不到這個章節' }, '發表失敗，請稍後再試'))
  }
  finally {
    posting.value = false
  }
}

async function like(c: ApiComment) {
  if (!isLoggedIn.value) {
    message.info('請先登入')
    return
  }
  try {
    await toggleLike(c)
  }
  catch (e) {
    message.error(describeError(e, {}, '操作失敗'))
  }
}

async function remove(c: ApiComment) {
  try {
    await removeComment(c)
    message.success('已刪除留言')
  }
  catch (e) {
    message.error(describeError(e, {}, '刪除失敗'))
  }
}

function openReport(c: ApiComment) {
  if (!isLoggedIn.value) {
    message.info('請先登入')
    return
  }
  reportTarget.value = c.id
  reportOpen.value = true
}

watch(sort, () => load())
watch(() => props.chapterId, () => load())
onMounted(() => load())
</script>
