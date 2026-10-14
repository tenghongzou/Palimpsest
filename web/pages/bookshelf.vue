<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <h1 class="text-xl font-bold">我的書架</h1>
      <div class="flex items-center gap-2">
        <n-select v-model:value="sortBy" :options="sortOptions" size="small" class="w-32" />
        <n-button size="small" :type="managing ? 'primary' : 'default'" data-testid="bookshelf-manage" @click="toggleManage">
          {{ managing ? '完成' : '管理' }}
        </n-button>
      </div>
    </div>

    <n-tabs v-if="groups.length > 1" v-model:value="activeGroup" type="line" size="small">
      <n-tab name="__all" :tab="`全部（${items.length}）`" />
      <n-tab v-for="g in groups" :key="g" :name="g" :tab="`${groupLabel(g)}（${countIn(g)}）`" />
    </n-tabs>

    <div v-if="managing" class="flex items-center gap-3 flex-wrap p-3 rounded bg-gray-50" data-testid="bookshelf-batch-bar">
      <n-checkbox :checked="allSelected" :indeterminate="someSelected" @update:checked="selectAll">全選</n-checkbox>
      <span class="text-sm text-gray-500">已選 {{ selected.size }} 本</span>
      <n-button size="small" :disabled="!selected.size" data-testid="bookshelf-move-selected" @click="openMove([...selected])">
        移動到分組
      </n-button>
      <n-popconfirm @positive-click="removeSelected">
        <template #trigger>
          <n-button size="small" type="error" :disabled="!selected.size" :loading="removing" data-testid="bookshelf-remove-selected">
            移除所選
          </n-button>
        </template>
        確定從書架移除 {{ selected.size }} 本書？
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
                有更新
              </n-tag>
            </div>
            <div class="flex-1 min-w-0 space-y-1">
              <div class="font-semibold truncate" data-testid="bookshelf-title">{{ item.novel?.title }}</div>
              <div class="text-sm text-gray-500 truncate">{{ item.novel?.author_name }}</div>
              <template v-if="item.reading_progress">
                <div class="text-xs text-gray-500 truncate" data-testid="bookshelf-progress">
                  讀到：第 {{ item.reading_progress.chapter_number }} 章 {{ item.reading_progress.chapter_title }}
                </div>
                <n-progress
                  type="line"
                  :percentage="Math.round(item.reading_progress.percentage ?? 0)"
                  :height="6"
                  indicator-placement="outside"
                />
                <div v-if="item.reading_progress.read_at" class="text-xs text-gray-400">
                  {{ formatRelativeTime(item.reading_progress.read_at) }}
                </div>
              </template>
              <div v-else class="text-xs text-gray-400">尚未開始閱讀</div>
              <div class="flex items-center gap-2 pt-1" @click.stop>
                <n-tag size="tiny" :bordered="false">{{ groupLabel(item.group_name) }}</n-tag>
                <n-button text size="tiny" data-testid="bookshelf-move" @click="openMove([item.novel_id])">分組</n-button>
                <n-popconfirm @positive-click="handleRemove(item.novel_id)">
                  <template #trigger>
                    <n-button text size="tiny" type="error">移除</n-button>
                  </template>
                  確定從書架移除？
                </n-popconfirm>
              </div>
            </div>
          </div>
        </n-card>
      </div>
      <n-empty v-if="!loading && items.length === 0" description="書架還是空的，去逛逛書城吧">
        <template #extra>
          <n-button type="primary" @click="navigateTo('/')">去看看</n-button>
        </template>
      </n-empty>
    </n-spin>

    <n-modal v-model:show="moveOpen" preset="card" title="移動到分組" style="max-width: 400px">
      <n-select
        v-model:value="moveTarget"
        :options="groupOptions"
        filterable
        tag
        placeholder="選擇或輸入新的分組名稱"
        data-testid="bookshelf-group-select"
      />
      <div class="text-xs text-gray-400 mt-2">輸入新名稱即可建立分組（最多 50 字）。</div>
      <template #footer>
        <div class="flex justify-end gap-2">
          <n-button @click="moveOpen = false">取消</n-button>
          <n-button type="primary" :loading="moving" :disabled="!moveTarget" data-testid="bookshelf-move-confirm" @click="confirmMove">
            移動
          </n-button>
        </div>
      </template>
    </n-modal>
  </div>
</template>

<script setup lang="ts">
import {
  NSpin, NCard, NButton, NSelect, NEmpty, NTabs, NTab, NCheckbox, NPopconfirm, NTag, NProgress, NModal, useMessage,
} from 'naive-ui'
import { formatRelativeTime } from '~/utils/format'

definePageMeta({ middleware: 'auth' })
useHead({ title: '書架 — Palimpsest' })

const message = useMessage()
const router = useRouter()
const { items, loading, fetchBookshelf, removeFromBookshelf, removeMany, moveToGroup } = useBookshelf()
const sortBy = ref<BookshelfSort>('recent')
const activeGroup = ref('__all')
const managing = ref(false)
const selected = ref(new Set<string>())
const removing = ref(false)
const moveOpen = ref(false)
const moveIds = ref<string[]>([])
const moveTarget = ref<string | null>(null)
const moving = ref(false)

const sortOptions = [
  { label: '最近閱讀', value: 'recent' },
  { label: '加入時間', value: 'added' },
  { label: '書名排序', value: 'title' },
]

const groups = computed(() => bookshelfGroups(items.value))
const groupOptions = computed(() => groups.value.map(g => ({ label: groupLabel(g), value: g })))
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

async function handleRemove(novelId: string) {
  try {
    await removeFromBookshelf(novelId)
    message.success('已從書架移除')
  }
  catch (e) {
    message.error(describeError(e, {}, '移除失敗'))
  }
}

async function removeSelected() {
  removing.value = true
  try {
    const ids = [...selected.value]
    await removeMany(ids)
    selected.value = new Set()
    message.success(`已移除 ${ids.length} 本書`)
  }
  catch (e) {
    message.error(describeError(e, {}, '移除失敗'))
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
    message.error('分組名稱最多 50 字')
    return
  }
  moving.value = true
  try {
    for (const id of moveIds.value) await moveToGroup(id, target)
    message.success(`已移動到「${groupLabel(target)}」`)
    moveOpen.value = false
    selected.value = new Set()
  }
  catch (e) {
    message.error(describeError(e, { 400: '分組名稱不正確' }, '移動失敗'))
  }
  finally {
    moving.value = false
  }
}

watch(groups, (list) => {
  if (activeGroup.value !== '__all' && !list.includes(activeGroup.value)) activeGroup.value = '__all'
})
watch(sortBy, (val) => {
  fetchBookshelf(val).catch(e => message.error(describeError(e, {}, '無法載入書架')))
}, { immediate: true })
</script>
