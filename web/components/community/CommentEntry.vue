<template>
  <div class="flex gap-3">
    <n-avatar :src="comment.user?.avatar_url || undefined" :size="compact ? 24 : 32" round class="flex-shrink-0">
      <template v-if="!comment.user?.avatar_url">{{ name.slice(0, 1) }}</template>
    </n-avatar>
    <div class="flex-1 min-w-0">
      <div class="flex items-center gap-2 text-xs text-gray-500">
        <span class="comment-author font-medium">{{ name }}</span>
        <span>{{ comment.created_at ? formatRelativeTime(comment.created_at) : '' }}</span>
        <n-tag v-if="comment.paragraph_index != null && !hideParagraph" size="tiny" :bordered="false">{{ $t('reader.paragraph.label', { n: comment.paragraph_index + 1 }) }}</n-tag>
      </div>
      <div class="text-sm mt-1 whitespace-pre-wrap break-words" data-testid="comment-content">{{ comment.content }}</div>
      <div class="flex items-center gap-3 mt-1">
        <n-button text size="tiny" :type="comment.liked_by_me ? 'primary' : 'default'" data-testid="comment-like" @click="emit('like')">
          {{ comment.liked_by_me ? $t('community.liked') : $t('community.like') }} {{ comment.like_count || '' }}
        </n-button>
        <n-button text size="tiny" @click="emit('reply')">{{ $t('comments.reply') }}</n-button>
        <n-popconfirm v-if="canDelete" @positive-click="emit('remove')">
          <template #trigger>
            <n-button text size="tiny" type="error">{{ $t('common.delete') }}</n-button>
          </template>
          {{ compact ? $t('comments.confirmDeleteReply') : $t('comments.confirmDeleteThread') }}
        </n-popconfirm>
        <n-button v-else text size="tiny" @click="emit('report')">{{ $t('community.report.action') }}</n-button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NAvatar, NButton, NPopconfirm, NTag } from 'naive-ui'
import type { ApiComment } from '~/types/models'

const props = defineProps<{
  comment: ApiComment
  canDelete: boolean
  compact?: boolean
  /** Hide the paragraph tag (when the list is already about one paragraph). */
  hideParagraph?: boolean
}>()

const emit = defineEmits<{
  like: []
  reply: []
  remove: []
  report: []
}>()

const { t, formatRelativeTime } = useFormat()
const name = computed(() => props.comment.user?.nickname || props.comment.user?.username || t('comments.anonymous'))
</script>

<style scoped>
/* Inherits the text color so it reads on light and dark reader themes. */
.comment-author {
  color: inherit;
  opacity: 0.85;
}
</style>
