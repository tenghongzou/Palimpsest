<template>
  <div class="flex items-center justify-between w-full">
    <div class="flex items-center gap-6">
      <NuxtLink to="/" class="text-xl font-bold text-primary no-underline">
        Palimpsest
      </NuxtLink>
      <n-menu
        mode="horizontal"
        :options="navOptions"
        :value="activeNav"
        @update:value="handleNavSelect"
      />
    </div>

    <div class="flex items-center gap-4">
      <n-input
        v-model:value="searchQuery"
        placeholder="搜尋小說..."
        clearable
        size="small"
        class="w-48"
        @keyup.enter="handleSearch"
      >
        <template #prefix>
          <n-icon :component="SearchIcon" />
        </template>
      </n-input>

      <n-dropdown
        v-if="isLoggedIn"
        :options="userMenuOptions"
        @select="handleUserMenuSelect"
      >
        <n-button quaternary circle>
          <template #icon>
            <n-avatar
              v-if="user?.avatar_url"
              :src="user.avatar_url"
              :size="28"
              round
            />
            <n-icon v-else :component="PersonIcon" :size="20" />
          </template>
        </n-button>
      </n-dropdown>

      <template v-else>
        <n-button size="small" @click="navigateTo('/login')">登入</n-button>
        <n-button size="small" type="primary" @click="navigateTo('/register')">註冊</n-button>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  NMenu, NInput, NIcon, NButton, NDropdown, NAvatar,
} from 'naive-ui'
import type { MenuOption, DropdownOption } from 'naive-ui'
import { Search as SearchIcon, Person as PersonIcon } from '@vicons/ionicons5'
import { h } from 'vue'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const isLoggedIn = computed(() => authStore.isLoggedIn)
const user = computed(() => authStore.user)

const searchQuery = ref('')

const activeNav = computed(() => {
  const path = route.path
  if (path.startsWith('/category')) return '/category'
  if (path.startsWith('/ranking')) return '/ranking'
  if (path.startsWith('/bookshelf')) return '/bookshelf'
  return '/'
})

const navOptions: MenuOption[] = [
  { label: () => h(resolveComponent('NuxtLink'), { to: '/' }, () => '首頁'), key: '/' },
  { label: () => h(resolveComponent('NuxtLink'), { to: '/category' }, () => '分類'), key: '/category' },
  { label: () => h(resolveComponent('NuxtLink'), { to: '/ranking' }, () => '排行'), key: '/ranking' },
  { label: () => h(resolveComponent('NuxtLink'), { to: '/bookshelf' }, () => '書架'), key: '/bookshelf' },
]

const userMenuOptions: DropdownOption[] = [
  { label: '個人中心', key: 'profile' },
  { label: '我的書架', key: 'bookshelf' },
  { type: 'divider', key: 'd1' },
  { label: '登出', key: 'logout' },
]

function handleNavSelect(key: string) {
  router.push(key)
}

function handleSearch() {
  if (searchQuery.value.trim()) {
    router.push({ path: '/search', query: { q: searchQuery.value.trim() } })
  }
}

async function handleUserMenuSelect(key: string) {
  switch (key) {
    case 'profile':
      router.push('/profile')
      break
    case 'bookshelf':
      router.push('/bookshelf')
      break
    case 'logout':
      await authStore.logout()
      router.push('/')
      break
  }
}
</script>
