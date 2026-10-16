<template>
  <div
    class="moderation-item rounded-lg border border-solid border-gray-500/20 p-4 space-y-2"
    :class="{ 'moderation-item--selected': selected }"
    :data-testid="`moderation-item-${item.id}`"
  >
    <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
      <n-checkbox :checked="selected" :disabled="!!busy" :aria-label="$t('admin.moderationQueue.select')" @update:checked="emit('toggle', $event)" />
      <n-tag size="small" :bordered="false" :type="item.type === 'review' ? 'info' : 'default'">{{ $t(`admin.reports.targets.${item.type}`) }}</n-tag>
      <n-tag size="small" :type="moderationTagType(item.status)">{{ moderationLabel(item.status) }}</n-tag>
      <span class="font-medium">{{ item.user?.nickname || item.user?.username }}</span>
      <span v-if="item.user?.username" class="text-gray-500">@{{ item.user.username }}</span>
      <span class="text-gray-500 text-xs ml-auto">{{ dateTime(item.created_at) }}</span>
    </div>

    <div class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-gray-500">
      <NuxtLink v-if="item.novel?.id" :to="`/novel/${item.novel.id}`" target="_blank" class="text-primary">{{ item.novel.title }}</NuxtLink>
      <template v-if="item.chapter?.id">
        <span aria-hidden="true">/</span>
        <NuxtLink :to="chapterLink" target="_blank" class="text-primary">{{ chapterText }}</NuxtLink>
      </template>
      <n-rate v-if="item.type === 'review' && item.rating" :value="item.rating" readonly allow-half size="small" />
    </div>

    <div>
      <div v-if="item.title" class="font-semibold">{{ item.title }}</div>
      <div class="text-sm whitespace-pre-wrap break-words" :class="{ 'line-clamp-3': !expanded }" data-testid="moderation-content">{{ item.content }}</div>
      <n-button v-if="long" text size="tiny" type="primary" @click="expanded = !expanded">
        {{ expanded ? $t('admin.moderationQueue.collapse') : $t('admin.moderationQueue.expand') }}
      </n-button>
    </div>

    <div v-if="item.moderation" class="flex flex-wrap items-center gap-x-3 gap-y-2" data-testid="moderation-result">
      <div class="flex items-center gap-2 w-44">
        <span class="text-xs text-gray-500 whitespace-nowrap">{{ $t('admin.moderationQueue.risk') }}</span>
        <n-progress
          type="line"
          :percentage="percent"
          :status="riskStatus(level)"
          :height="6"
          :show-indicator="false"
          class="flex-1"
        />
        <span class="text-xs font-medium tabular-nums" :class="RISK_TEXT[level]">{{ percent }}%</span>
      </div>
      <n-tag
        v-for="(flag, i) in item.moderation.flags"
        :key="`${flag.code}-${i}`"
        size="small"
        round
        :type="flag.code === 'blocked_term' ? 'error' : 'warning'"
        data-testid="moderation-flag"
      >{{ flagText(t, flag) }}</n-tag>
      <span v-if="!item.moderation.flags.length" class="text-xs text-gray-500">{{ $t('admin.moderationQueue.noFlags') }}</span>
      <n-tag v-if="item.moderation.ai_checked" size="small" :bordered="false" type="success" data-testid="ai-checked">
        {{ $t('admin.moderationQueue.aiChecked') }}
      </n-tag>
      <span v-else class="text-xs text-gray-400">{{ $t('admin.moderationQueue.aiNotChecked') }}</span>
    </div>

    <div class="flex flex-wrap gap-2 pt-1">
      <n-button size="small" type="primary" :loading="busy === 'approved'" :disabled="!!busy" @click="emit('decide', 'approved')">
        {{ $t('admin.reviews.actions.approved') }}
      </n-button>
      <n-popconfirm v-for="action in CONFIRMED" :key="action" @positive-click="emit('decide', action)">
        <template #trigger>
          <n-button size="small" :type="action === 'rejected' ? 'error' : 'warning'" secondary :loading="busy === action" :disabled="!!busy">
            {{ $t(`admin.reviews.actions.${action}`) }}
          </n-button>
        </template>
        {{ $t(`admin.moderationQueue.confirm.${action}`, { type: $t(`admin.reports.targets.${item.type}`) }) }}
      </n-popconfirm>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NButton, NCheckbox, NPopconfirm, NProgress, NRate, NTag } from 'naive-ui'
import type { ApiModerationItem } from '~/types/models'
import { flagText, riskLevel, riskPercent, riskStatus, type ModerationDecision } from '~/utils/moderation'

const props = defineProps<{
  item: ApiModerationItem
  selected?: boolean
  /** The decision being saved, if any. */
  busy?: ModerationDecision | null
}>()

const emit = defineEmits<{
  toggle: [checked: boolean]
  decide: [status: ModerationDecision]
}>()

const { t } = useI18n()
const { chapterLabel } = useFormat()
const { moderationLabel, dateTime } = useAdminLabels()

const CONFIRMED = ['rejected', 'hidden'] as const
const RISK_TEXT = { low: 'text-green-600', medium: 'text-orange-500', high: 'text-red-500' } as const

const expanded = ref(false)
const long = computed(() => props.item.content.length > 160 || props.item.content.split('\n').length > 3)
const percent = computed(() => riskPercent(props.item.moderation?.score))
const level = computed(() => riskLevel(props.item.moderation?.score))

const chapterText = computed(() => {
  const c = props.item.chapter
  if (!c) return ''
  return typeof c.chapter_number === 'number' ? chapterLabel(c.chapter_number, c.title ?? '') : (c.title ?? '')
})
// Published comments can be focused in the reader; pending ones are not public yet.
const chapterLink = computed(() => {
  const base = `/read/${props.item.chapter?.id}`
  return props.item.status === 'approved' ? `${base}?comment=${props.item.id}` : base
})
</script>

<style scoped>
.moderation-item--selected {
  border-color: var(--color-primary);
  background: rgba(24, 144, 255, 0.04);
}
</style>
