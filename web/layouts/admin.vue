<template>
  <n-config-provider :theme-overrides="brandThemeOverrides" :locale="naiveLocale" :date-locale="naiveDateLocale">
    <n-message-provider>
      <PwaPrompt />
      <n-dialog-provider>
        <n-layout has-sider class="min-h-screen">
          <n-layout-sider
            v-model:collapsed="collapsed"
            bordered
            collapse-mode="width"
            :collapsed-width="64"
            :width="200"
            show-trigger
            class="min-h-screen"
            content-style="padding: 12px 0;"
          >
            <NuxtLink to="/admin" class="admin-brand flex flex-col items-center gap-1 py-3" data-testid="admin-brand">
              <BrandLogo v-if="collapsed" variant="mark" :height="32" />
              <template v-else>
                <BrandLogo variant="horizontal" :height="28" />
                <span class="text-xs font-semibold tracking-widest uppercase text-gray-400">{{ $t('admin.layout.brand') }}</span>
              </template>
            </NuxtLink>
            <n-menu
              :options="menuOptions"
              :value="activeMenu"
              @update:value="handleMenuSelect"
            />
          </n-layout-sider>
          <n-layout>
            <n-layout-header bordered class="px-3 md:px-6 py-3 flex items-center justify-between gap-2">
              <span class="text-lg font-semibold truncate hidden sm:inline">{{ $t('admin.layout.title') }}</span>
              <div class="flex items-center gap-3 md:gap-4 text-sm ml-auto">
                <NuxtLink to="/" class="text-gray-600 whitespace-nowrap">{{ $t('admin.layout.backToSite') }}</NuxtLink>
                <LanguageSwitcher />
                <span class="text-gray-500 hidden md:inline">{{ authStore.user?.nickname || authStore.user?.username }}</span>
                <n-button size="small" @click="handleLogout">{{ $t('common.logout') }}</n-button>
              </div>
            </n-layout-header>
            <n-layout-content :content-style="{ padding: narrow ? '12px' : '24px' }">
              <slot />
            </n-layout-content>
          </n-layout>
        </n-layout>
      </n-dialog-provider>
    </n-message-provider>
  </n-config-provider>
</template>

<script setup lang="ts">
import {
  NConfigProvider, NMessageProvider, NDialogProvider, NLayout, NLayoutSider,
  NLayoutHeader, NLayoutContent, NMenu, NButton, NBadge, NIcon,
} from 'naive-ui'
import { h } from 'vue'
import {
  BookOutline, ChatboxEllipsesOutline, FlagOutline, FolderOutline, GridOutline, ImagesOutline, MegaphoneOutline,
  PeopleOutline, ShieldCheckmarkOutline,
} from '@vicons/ionicons5'
import type { MenuOption } from 'naive-ui'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const { t } = useI18n()
const { naiveLocale, naiveDateLocale } = useNaiveLocale()

// The sider shows the full logo, or just the mark once collapsed to 64px.
// Narrow screens start collapsed so the content keeps most of the width.
const narrow = useMediaQuery('(max-width: 767px)')
const collapsed = ref(false)
watch(narrow, (value) => { collapsed.value = value }, { immediate: true })

const MENU = [
  { labelKey: 'admin.menu.dashboard', icon: GridOutline, key: '/admin' },
  { labelKey: 'admin.menu.novels', icon: BookOutline, key: '/admin/novels' },
  { labelKey: 'admin.menu.users', icon: PeopleOutline, key: '/admin/users' },
  { labelKey: 'admin.menu.moderation', icon: ShieldCheckmarkOutline, key: '/admin/moderation' },
  { labelKey: 'admin.menu.reviews', icon: ChatboxEllipsesOutline, key: '/admin/reviews' },
  { labelKey: 'admin.menu.reports', icon: FlagOutline, key: '/admin/reports' },
  { labelKey: 'admin.menu.categories', icon: FolderOutline, key: '/admin/categories' },
  { labelKey: 'admin.menu.banners', icon: ImagesOutline, key: '/admin/banners' },
  { labelKey: 'admin.menu.announcements', icon: MegaphoneOutline, key: '/admin/notifications' },
]
// The moderation entry shows how many reviews and comments await a decision.
const pendingModeration = usePendingModeration()
const menuOptions = computed<MenuOption[]>(() => MENU.map((m) => {
  const count = m.key === '/admin/moderation' ? pendingModeration.count.value : null
  return {
    key: m.key,
    // Collapsed, only icons show; a dot marks pending moderation.
    icon: () => h(NBadge, { dot: true, show: !!count && collapsed.value, offset: [2, -2] }, () => h(NIcon, null, () => h(m.icon))),
    label: count
      ? () => h('span', { class: 'inline-flex items-center gap-2', 'data-testid': 'admin-menu-moderation' }, [
          t(m.labelKey),
          h(NBadge, { value: count, max: 99 }),
        ])
      : t(m.labelKey),
  }
}))

// Read once on entering the console; the dashboard and moderation page keep it current.
onMounted(() => {
  if (route.path !== '/admin') void pendingModeration.refresh()
})

// The longest menu key that prefixes the current path, so sub-pages such as
// /admin/novels/:id/chapters keep their section highlighted.
const activeMenu = computed(() => {
  const keys = MENU.map(o => o.key)
  return keys
    .filter(k => route.path === k || route.path.startsWith(`${k}/`))
    .sort((a, b) => b.length - a.length)[0] ?? '/admin'
})

function handleMenuSelect(key: string) {
  router.push(key)
}

async function handleLogout() {
  await authStore.logout()
  router.push('/login')
}
</script>

<style scoped>
.admin-brand:hover {
  text-decoration: none;
}
</style>
