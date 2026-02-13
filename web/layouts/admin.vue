<template>
  <n-config-provider>
    <n-message-provider>
      <n-layout has-sider class="min-h-screen">
        <n-layout-sider
          bordered
          collapse-mode="width"
          :collapsed-width="64"
          :width="220"
          show-trigger
          class="h-screen"
          content-style="padding: 12px;"
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
            <span class="text-lg font-semibold">Palimpsest Admin</span>
          </n-layout-header>
          <n-layout-content class="p-6">
            <slot />
          </n-layout-content>
        </n-layout>
      </n-layout>
    </n-message-provider>
  </n-config-provider>
</template>

<script setup lang="ts">
import {
  NConfigProvider, NMessageProvider, NLayout, NLayoutSider,
  NLayoutHeader, NLayoutContent, NMenu,
} from 'naive-ui'
import type { MenuOption } from 'naive-ui'
import { h } from 'vue'

const router = useRouter()
const route = useRoute()

const activeMenu = computed(() => route.path)

const menuOptions: MenuOption[] = [
  { label: () => h('span', '小說管理'), key: '/admin' },
  { label: () => h('span', '用戶管理'), key: '/admin/users' },
  { label: () => h('span', '內容審核'), key: '/admin/reviews' },
  { label: () => h('span', '數據統計'), key: '/admin/stats' },
]

function handleMenuSelect(key: string) {
  router.push(key)
}
</script>
