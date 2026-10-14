<template>
  <n-config-provider :theme-overrides="brandThemeOverrides" :locale="naiveLocale" :date-locale="naiveDateLocale">
    <n-message-provider>
      <PwaPrompt />
      <n-dialog-provider>
        <n-layout has-sider class="min-h-screen">
          <n-layout-sider
            bordered
            collapse-mode="width"
            :collapsed-width="64"
            :width="200"
            show-trigger
            class="min-h-screen"
            content-style="padding: 12px 0;"
          >
            <div class="text-center py-4 font-bold text-lg">{{ $t('admin.layout.brand') }}</div>
            <n-menu
              :options="menuOptions"
              :value="activeMenu"
              @update:value="handleMenuSelect"
            />
          </n-layout-sider>
          <n-layout>
            <n-layout-header bordered class="px-6 py-3 flex items-center justify-between">
              <span class="text-lg font-semibold">{{ $t('admin.layout.title') }}</span>
              <div class="flex items-center gap-4 text-sm">
                <NuxtLink to="/" class="text-gray-600">{{ $t('admin.layout.backToSite') }}</NuxtLink>
                <LanguageSwitcher />
                <span class="text-gray-500">{{ authStore.user?.nickname || authStore.user?.username }}</span>
                <n-button size="small" @click="handleLogout">{{ $t('common.logout') }}</n-button>
              </div>
            </n-layout-header>
            <n-layout-content content-style="padding: 24px;">
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
  NLayoutHeader, NLayoutContent, NMenu, NButton,
} from 'naive-ui'
import type { MenuOption } from 'naive-ui'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const { t } = useI18n()
const { naiveLocale, naiveDateLocale } = useNaiveLocale()

const MENU = [
  { labelKey: 'admin.menu.dashboard', key: '/admin' },
  { labelKey: 'admin.menu.novels', key: '/admin/novels' },
  { labelKey: 'admin.menu.users', key: '/admin/users' },
  { labelKey: 'admin.menu.reviews', key: '/admin/reviews' },
  { labelKey: 'admin.menu.reports', key: '/admin/reports' },
  { labelKey: 'admin.menu.categories', key: '/admin/categories' },
  { labelKey: 'admin.menu.banners', key: '/admin/banners' },
  { labelKey: 'admin.menu.announcements', key: '/admin/notifications' },
]
const menuOptions = computed<MenuOption[]>(() => MENU.map(m => ({ label: t(m.labelKey), key: m.key })))

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
