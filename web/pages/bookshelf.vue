<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <h1 class="text-xl font-bold">{{ $t('bookshelf.heading') }}</h1>
      <div class="flex items-center gap-2">
        <n-select v-model:value="sortBy" :options="sortOptions" size="small" class="w-32" />
        <n-button size="small" :type="managing ? 'primary' : 'default'" data-testid="bookshelf-manage" @click="toggleManage">
          {{ managing ? $t('bookshelf.done') : $t('bookshelf.manage') }}
        </n-button>
      </div>
    </div>
    <n-alert v-if="offline" type="info" :show-icon="false" data-testid="bookshelf-offline">
      {{ $t('bookshelf.offlineNotice') }}
    </n-alert>

    <n-tabs v-if="groups.length > 1" v-model:value="activeGroup" type="line" size="small">
      <n-tab name="__all" :tab="$t('bookshelf.groupTab', { name: $t('common.all'), n: items.length })" />
      <n-tab v-for="g in groups" :key="g" :name="g" :tab="$t('bookshelf.groupTab', { name: groupLabel(g, t), n: countIn(g) })" />
    </n-tabs>

    <div v-if="managing" class="flex items-center gap-3 flex-wrap p-3 rounded bg-gray-50" data-testid="bookshelf-batch-bar">
      <n-checkbox :checked="allSelected" :indeterminate="someSelected" @update:checked="selectAll">{{ $t('bookshelf.selectAll') }}</n-checkbox>
      <span class="text-sm text-gray-500">{{ $t('bookshelf.selectedCount', { n: selected.size }, selected.size) }}</span>
      <n-button size="small" :disabled="!selected.size" data-testid="bookshelf-move-selected" @click="openMove([...selected])">
        {{ $t('bookshelf.moveToGroup') }}
      </n-button>
      <n-popconfirm @positive-click="removeSelected">
        <template #trigger>
          <n-button size="small" type="error" :disabled="!selected.size" :loading="removing" data-testid="bookshelf-remove-selected">
            {{ $t('bookshelf.removeSelected') }}
          </n-button>
        </template>
        {{ $t('bookshelf.confirmRemoveMany', { n: selected.size }, selected.size) }}
      </n-popconfirm>
    </div>

    <n-spin :show="loading">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <n-card
          v-for="item in visibleItems"
          :key="item.id"
          hoverable
          class="cursor-pointer"
          :class="{ 'ring-2 ring-blue-400': managing && selected.has(item.novel_id) }"
          data-testid="bookshelf-item"
          @click="onCardClick(item)"
        >
          <div class="flex gap-3">
            <n-checkbox
              v-if="managing"
              :checked="selected.has(item.novel_id)"
              class="self-start"
              @click.stop
              @update:checked="toggle(item.novel_id)"
            />
            <div class="relative">
              <NovelCover :src="item.novel?.cover_url" :alt="item.novel?.title" :width="60" :height="84" />
              <n-tag v-if="item.has_update" type="error" size="tiny" round class="absolute -top-2 -right-2" data-testid="bookshelf-has-update">
                {{ $t('bookshelf.hasUpdate') }}
              </n-tag>
            </div>
            <div class="flex-1 min-w-0 space-y-1">
              <div class="font-semibold truncate" data-testid="bookshelf-title">{{ item.novel?.title }}</div>
              <div class="text-sm text-gray-500 truncate">{{ item.novel?.author_name }}</div>
              <template v-if="item.reading_progress">
                <div class="text-xs text-gray-500 truncate" data-testid="bookshelf-progress">
                  {{ $t('bookshelf.progress', { label: chapterLabel(item.reading_progress.chapter_number ?? 0, item.reading_progress.chapter_title ?? '') }) }}
                </div>
                <n-progress
                  v-if="item.reading_progress.percentage != null"
                  type="line"
                  :percentage="Math.round(item.reading_progress.percentage ?? 0)"
                  :height="6"
                  indicator-placement="outside"
                />
                <div v-if="item.reading_progress.read_at" class="text-xs text-gray-400">
                  {{ formatRelativeTime(item.reading_progress.read_at) }}
                </div>
              </template>
              <div v-else class="text-xs text-gray-400">{{ $t('bookshelf.notStarted') }}</div>
              <div class="flex items-center flex-wrap gap-x-2 gap-y-1 pt-1" @click.stop>
                <n-tag size="tiny" :bordered="false">{{ groupLabel(item.group_name, t) }}</n-tag>
                <n-button text size="tiny" data-testid="bookshelf-move" @click="openMove([item.novel_id])">{{ $t('bookshelf.group') }}</n-button>
                <n-button
                  text
                  size="tiny"
                  :type="isNotified(item) ? 'primary' : 'default'"
                  :aria-pressed="isNotified(item)"
                  :title="isNotified(item) ? $t('bookshelf.notifyOnTitle') : $t('bookshelf.notifyOffTitle')"
                  :disabled="togglingNotify.has(item.novel_id)"
                  data-testid="bookshelf-notify"
                  @click="toggleNotified(item)"
                >
                  <template #icon>
                    <n-icon :component="isNotified(item) ? NotificationsOutline : NotificationsOffOutline" />
                  </template>
                  {{ isNotified(item) ? $t('bookshelf.notifyOn') : $t('bookshelf.notifyOff') }}
                </n-button>
                <n-popconfirm @positive-click="handleRemove(item.novel_id)">
                  <template #trigger>
                    <n-button text size="tiny" type="error">{{ $t('devices.remove') }}</n-button>
                  </template>
                  {{ $t('bookshelf.confirmRemove') }}
                </n-popconfirm>
              </div>
            </div>
          </div>
        </n-card>
      </div>
      <n-empty v-if="!loading && items.length === 0" :description="$t('bookshelf.empty')">
        <template #extra>
          <n-button type="primary" @click="navigateTo('/')">{{ $t('bookshelf.browse') }}</n-button>
        </template>
      </n-empty>
    </n-spin>

    <n-modal v-model:show="moveOpen" preset="card" :title="$t('bookshelf.moveToGroup')" style="max-width: 400px">
      <n-select
        v-model:value="moveTarget"
        :options="groupOptions"
        filterable
        tag
        :placeholder="$t('bookshelf.groupPlaceholder')"
        data-testid="bookshelf-group-select"
      />
      <div class="text-xs text-gray-400 mt-2">{{ $t('bookshelf.groupHint', { max: 50 }) }}</div>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="moveOpen = false">{{ $t('common.cancel') }}</n-button>
          <n-button type="primary" :loading="moving" :disabled="!moveTarget" data-testid="bookshelf-move-confirm" @click="confirmMove">
            {{ $t('bookshelf.move') }}
          </n-button>
        </div>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import {
  NAlert, NSpin, NCard, NButton, NSelect, NEmpty, NTabs, NTab, NCheckbox, NPopconfirm, NTag, NProgress, NModal, NIcon, useMessage,
} from 'naive-ui'
import { NotificationsOutline, NotificationsOffOutline } from '@vicons/ionicons5'

definePageMeta({ middleware: 'auth' })

const { t, formatRelativeTime, chapterLabel } = useFormat()
useHead({ title: () => t('header.nav.bookshelf') })

const message = useMessage()
const router = useRouter()
const { items, loading, offline, fetchBookshelf, removeFromBookshelf, removeMany, moveToGroup, setNotified } = useBookshelf()
const togglingNotify = ref(new Set<string>())
const sortBy = ref<BookshelfSort>('recent')
const activeGroup = ref('__all')
const managing = ref(false)
const selected = ref(new Set<string>())
const removing = ref(false)
const moveOpen = ref(false)
const moveIds = ref<string[]>([])
const moveTarget = ref<string | null>(null)
const moving = ref(false)

const sortOptions = computed(() => (['recent', 'added', 'title'] as const).map(value => ({ label: t(`bookshelf.sort.${value}`), value })))

const groups = computed(() => bookshelfGroups(items.value))
const groupOptions = computed(() => groups.value.map(g => ({ label: groupLabel(g, t), value: g })))
const visibleItems = computed(() =>
  activeGroup.value === '__all'
    ? items.value
    : items.value.filter(i => (i.group_name || DEFAULT_GROUP) === activeGroup.value),
)
const allSelected = computed(() => visibleItems.value.length > 0 && visibleItems.value.every(i => selected.value.has(i.novel_id)))
const someSelected = computed(() => selected.value.size > 0 && !allSelected.value)

function countIn(group: string) {
  return items.value.filter(i => (i.group_name || DEFAULT_GROUP) === group).length
}

function toggleManage() {
  managing.value = !managing.value
  selected.value = new Set()
}

function toggle(novelId: string) {
  const next = new Set(selected.value)
  if (next.has(novelId)) next.delete(novelId)
  else next.add(novelId)
  selected.value = next
}

function selectAll(checked: boolean) {
  selected.value = checked ? new Set(visibleItems.value.map(i => i.novel_id)) : new Set()
}

function onCardClick(item: BookshelfEntry) {
  if (managing.value) {
    toggle(item.novel_id)
    return
  }
  const chapterId = item.reading_progress?.chapter_id
  router.push(chapterId ? `/read/${chapterId}` : `/novel/${item.novel_id}`)
}

async function toggleNotified(item: BookshelfEntry) {
  const id = item.novel_id
  const on = !isNotified(item)
  togglingNotify.value = new Set(togglingNotify.value).add(id)
  try {
    await setNotified(id, on)
    message.success(on ? t('bookshelf.notifyEnabled') : t('bookshelf.notifyDisabled'))
  }
  catch (e) {
    message.error(describeError(t, e, { 404: t('bookshelf.notOnShelf') }, t('bookshelf.notifyFailed')))
  }
  finally {
    const next = new Set(togglingNotify.value)
    next.delete(id)
    togglingNotify.value = next
  }
}

async function handleRemove(novelId: string) {
  try {
    await removeFromBookshelf(novelId)
    message.success(t('bookshelf.removed'))
  }
  catch (e) {
    message.error(describeError(t, e, {}, t('bookshelf.removeFailed')))
  }
}

async function removeSelected() {
  removing.value = true
  try {
    const ids = [...selected.value]
    await removeMany(ids)
    selected.value = new Set()
    message.success(t('bookshelf.removedMany', { n: ids.length }, ids.length))
  }
  catch (e) {
    message.error(describeError(t, e, {}, t('bookshelf.removeFailed')))
  }
  finally {
    removing.value = false
  }
}

function openMove(novelIds: string[]) {
  moveIds.value = novelIds
  const current = items.value.find(i => i.novel_id === novelIds[0])?.group_name
  moveTarget.value = novelIds.length === 1 ? (current || DEFAULT_GROUP) : null
  moveOpen.value = true
}

async function confirmMove() {
  const target = moveTarget.value?.trim()
  if (!target) return
  if (target.length > 50) {
    message.error(t('bookshelf.groupTooLong', { max: 50 }))
    return
  }
  moving.value = true
  try {
    for (const id of moveIds.value) await moveToGroup(id, target)
    message.success(t('bookshelf.moved', { name: groupLabel(target, t) }))
    moveOpen.value = false
    selected.value = new Set()
  }
  catch (e) {
    message.error(describeError(t, e, { 400: t('bookshelf.groupInvalid') }, t('bookshelf.moveFailed')))
  }
  finally {
    moving.value = false
  }
}

watch(groups, (list) => {
  if (activeGroup.value !== '__all' && !list.includes(activeGroup.value)) activeGroup.value = '__all'
})
watch(sortBy, (val) => {
  fetchBookshelf(val).catch(e => message.error(describeError(t, e, {}, t('bookshelf.loadFailed'))))
}, { immediate: true })
</script>
