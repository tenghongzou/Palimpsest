<template>
  <div class="space-y-4" :data-testid="isParagraphMode ? 'paragraph-comments' : 'chapter-comments'">
    <div class="flex items-center justify-between">
      <span class="text-sm text-gray-500">{{ $t(isParagraphMode ? 'comments.totalParagraph' : 'comments.total', { n: pagination.total }, pagination.total) }}</span>
      <n-radio-group v-model:value="sort" size="small">
        <n-radio-button value="latest">{{ $t('comments.sortLatest') }}</n-radio-button>
        <n-radio-button value="popular">{{ $t('comments.sortPopular') }}</n-radio-button>
      </n-radio-group>
    </div>

    <div v-if="isLoggedIn" class="space-y-2">
      <div v-if="replyTo" class="text-xs text-gray-500 flex items-center gap-2">
        {{ $t('comments.replyingTo', { name: replyTo.user?.nickname || replyTo.user?.username || $t('comments.anonymous') }) }}
        <n-button text size="tiny" @click="replyTo = null">{{ $t('common.cancel') }}</n-button>
      </div>
      <n-input
        ref="inputRef"
        v-model:value="draft"
        type="textarea"
        :rows="3"
        maxlength="2000"
        show-count
        :placeholder="placeholder"
        data-testid="comment-input"
      />
      <div class="flex items-center justify-between">
        <n-checkbox v-if="!replyTo && !isParagraphMode && paragraphAttachable" v-model:checked="attachParagraph">
          {{ $t('comments.attachParagraph', { n: currentParagraph + 1 }) }}
        </n-checkbox>
        <span v-else />
        <n-button type="primary" size="small" :loading="posting" :disabled="!draft.trim()" data-testid="comment-submit" @click="post">
          {{ replyTo ? $t('comments.reply') : isParagraphMode ? $t('comments.postParagraph') : $t('comments.post') }}
        </n-button>
      </div>
    </div>
    <n-alert v-else type="info" :show-icon="false">
      <i18n-t keypath="comments.loginToComment" tag="span" scope="global">
        <template #login>
          <NuxtLink :to="`/login?redirect=${encodeURIComponent(route.fullPath)}`" class="text-primary">{{ $t('common.login') }}</NuxtLink>
        </template>
      </i18n-t>
    </n-alert>

    <n-spin :show="loading">
      <div class="space-y-4">
        <div
          v-for="c in items"
          :key="c.id"
          class="comment-thread border-b border-gray-100 pb-3"
          :class="{ 'comment-thread--focus': c.id === highlightedId }"
          :data-comment-id="c.id"
          data-testid="comment-item"
        >
          <CommentEntry
            :comment="c"
            :can-delete="canDelete(c)"
            :hide-paragraph="isParagraphMode"
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
              :hide-paragraph="isParagraphMode"
              compact
              @like="like(r)"
              @reply="startReply(c)"
              @remove="remove(r)"
              @report="openReport(r)"
            />
          </div>
        </div>
        <div v-if="!loading && loadFailed && items.length === 0" class="text-center text-sm text-gray-400 py-6" data-testid="comments-error">
          {{ $t('comments.loadFailed') }}
          <n-button text size="small" type="primary" @click="reload">{{ $t('common.retry') }}</n-button>
        </div>
        <div v-else-if="!loading && items.length === 0" class="text-center text-sm text-gray-400 py-6" data-testid="comments-empty">
          {{ isParagraphMode ? $t('comments.emptyParagraph') : $t('comments.empty') }}
        </div>
      </div>
    </n-spin>

    <div v-if="pagination.total_pages > 1" class="flex justify-center">
      <n-pagination :page="pagination.page" :page-count="pagination.total_pages" size="small" @update:page="loadPage" />
    </div>

    <ReportDialog v-model:show="reportOpen" target-type="comment" :target-id="reportTarget" />
  </div>
</template>

<script setup lang="ts">
import { NRadioGroup, NRadioButton, NInput, NButton, NCheckbox, NAlert, NSpin, NPagination, useMessage } from 'naive-ui'
import type { ApiComment } from '~/types/models'

const props = withDefaults(defineProps<{
  chapterId: string
  currentParagraph: number
  /** Paragraph mode: list and post comments on this paragraph only. */
  paragraphIndex?: number | null
  /** Thread to scroll to and highlight (from GET /comments/{id}, e.g. for a notification). */
  focusThread?: ApiComment | null
  /** Offer "針對目前段落" (off when the shown text's paragraphs differ, e.g. a translation). */
  paragraphAttachable?: boolean
}>(), {
  paragraphIndex: null,
  focusThread: null,
  paragraphAttachable: true,
})

const emit = defineEmits<{
  /** A top-level comment was posted or deleted (paragraph counts may change). */
  changed: []
}>()

const { t } = useI18n()
const route = useRoute()
const message = useMessage()
const authStore = useAuthStore()
const isLoggedIn = computed(() => authStore.isLoggedIn)
const isParagraphMode = computed(() => props.paragraphIndex !== null && props.paragraphIndex !== undefined)

const { items, pagination, sort, loading, load, create, remove: removeComment, toggleLike } = useComments(
  () => props.chapterId,
  { paragraphIndex: () => props.paragraphIndex },
)

const draft = ref('')
const posting = ref(false)
const attachParagraph = ref(false)
const replyTo = ref<ApiComment | null>(null)
const inputRef = ref<{ focus: () => void } | null>(null)
const reportOpen = ref(false)
const reportTarget = ref<string | null>(null)
const loadFailed = ref(false)
const highlightedId = ref<string | null>(null)

const placeholder = computed(() => {
  if (replyTo.value) return t('comments.placeholderReply')
  return isParagraphMode.value ? t('comments.placeholderParagraph') : t('comments.placeholderChapter')
})

function canDelete(c: ApiComment) {
  return c.user_id === authStore.user?.id || authStore.isAdmin
}

async function loadPage(page = 1) {
  loadFailed.value = false
  try {
    await load(page)
  }
  catch {
    loadFailed.value = true
  }
}

function reload() {
  return loadPage(1)
}

/**
 * Highlights a thread and scrolls to it. When it is not on the loaded page
 * (older or less popular), the fetched thread is shown at the top.
 */
async function showThread(thread: ApiComment) {
  const existing = items.value.find(c => c.id === thread.id)
  if (existing) existing.replies = thread.replies ?? existing.replies
  else items.value = [{ ...thread, replies: thread.replies ?? [] }, ...items.value]
  highlightedId.value = thread.id
  await nextTick()
  document.querySelector<HTMLElement>(`[data-comment-id="${thread.id}"]`)?.scrollIntoView({ block: 'center' })
  setTimeout(() => {
    if (highlightedId.value === thread.id) highlightedId.value = null
  }, 3000)
}

function startReply(c: ApiComment) {
  if (!isLoggedIn.value) {
    message.info(t('auth.loginFirst'))
    return
  }
  replyTo.value = c
  nextTick(() => inputRef.value?.focus())
}

async function post() {
  if (!draft.value.trim()) return
  posting.value = true
  try {
    const isReply = !!replyTo.value
    await create({
      content: draft.value,
      ...(replyTo.value ? { parent_id: replyTo.value.id } : {}),
      ...(!replyTo.value && !isParagraphMode.value && attachParagraph.value ? { paragraph_index: props.currentParagraph } : {}),
    })
    draft.value = ''
    replyTo.value = null
    attachParagraph.value = false
    message.success(isReply ? t('comments.replyPosted') : t('comments.posted'))
    if (!isReply) emit('changed')
  }
  catch (e) {
    message.error(describeError(t, e, { 400: t('comments.invalid'), 404: t('reader.chapterNotFound') }, t('comments.postFailed')))
  }
  finally {
    posting.value = false
  }
}

async function like(c: ApiComment) {
  if (!isLoggedIn.value) {
    message.info(t('auth.loginFirst'))
    return
  }
  try {
    await toggleLike(c)
  }
  catch (e) {
    message.error(describeError(t, e, {}, t('common.operationFailed')))
  }
}

async function remove(c: ApiComment) {
  try {
    await removeComment(c)
    message.success(t('comments.deleted'))
    if (!c.parent_id) emit('changed')
  }
  catch (e) {
    message.error(describeError(t, e, {}, t('common.deleteFailed')))
  }
}

function openReport(c: ApiComment) {
  if (!isLoggedIn.value) {
    message.info(t('auth.loginFirst'))
    return
  }
  reportTarget.value = c.id
  reportOpen.value = true
}

function resetComposer() {
  draft.value = ''
  replyTo.value = null
  attachParagraph.value = false
}

watch(sort, () => reload())
watch(() => [props.chapterId, props.paragraphIndex], async () => {
  resetComposer()
  await reload()
  if (props.focusThread) await showThread(props.focusThread)
})
// When the chapter changes too, the watcher above shows it after reloading.
watch(() => props.focusThread, (thread) => {
  if (thread && !loading.value) void showThread(thread)
})
onMounted(async () => {
  await reload()
  if (props.focusThread) await showThread(props.focusThread)
})
</script>

<style scoped>
.comment-thread {
  border-radius: 4px;
  transition: background-color 0.6s;
}
.comment-thread--focus {
  background-color: rgba(250, 204, 21, 0.25);
}
</style>
