<template>
  <n-config-provider :locale="zhTW" :date-locale="dateZhTW">
    <n-message-provider>
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
            <div class="text-center py-4 font-bold text-lg">Admin</div>
            <n-menu
              :options="menuOptions"
              :value="activeMenu"
              @update:value="handleMenuSelect"
            />
          </n-layout-sider>
          <n-layout>
            <n-layout-header bordered class="px-6 py-3 flex items-center justify-between">
              <span class="text-lg font-semibold">Palimpsest 管理後台</span>
              <div class="flex items-center gap-4 text-sm">
                <NuxtLink to="/" class="text-gray-600">回到前台</NuxtLink>
                <span class="text-gray-500">{{ authStore.user?.nickname || authStore.user?.username }}</span>
                <n-button size="small" @click="handleLogout">登出</n-button>
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
  NLayoutHeader, NLayoutContent, NMenu, NButton, zhTW, dateZhTW,
} from 'naive-ui'
import type { MenuOption } from 'naive-ui'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const menuOptions: MenuOption[] = [
  { label: '總覽', key: '/admin' },
  { label: '小說管理', key: '/admin/novels' },
  { label: '用戶管理', key: '/admin/users' },
  { label: '書評審核', key: '/admin/reviews' },
  { label: '檢舉處理', key: '/admin/reports' },
  { label: '分類管理', key: '/admin/categories' },
  { label: '橫幅管理', key: '/admin/banners' },
]

// The longest menu key that prefixes the current path, so sub-pages such as
// /admin/novels/:id/chapters keep their section highlighted.
const activeMenu = computed(() => {
  const keys = menuOptions.map(o => o.key as string)
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
