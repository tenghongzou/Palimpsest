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
        :placeholder="$t('header.searchPlaceholder')"
        clearable
        size="small"
        class="w-48"
        @keyup.enter="handleSearch"
      >
        <template #prefix>
          <n-icon :component="SearchIcon" />
        </template>
      </n-input>

      <LanguageSwitcher />

      <ClientOnly>
        <NotificationBell v-if="isLoggedIn" />
      </ClientOnly>

      <n-dropdown
        v-if="isLoggedIn"
        :options="userMenuOptions"
        @select="handleUserMenuSelect"
      >
        <n-button quaternary circle data-testid="user-menu">
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
        <n-button size="small" @click="navigateTo('/login')">{{ $t('common.login') }}</n-button>
        <n-button size="small" type="primary" @click="navigateTo('/register')">{{ $t('common.register') }}</n-button>
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

const { t } = useI18n()
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

const NAV = [
  { to: '/', labelKey: 'header.nav.home' },
  { to: '/category', labelKey: 'header.nav.categories' },
  { to: '/ranking', labelKey: 'header.nav.rankings' },
  { to: '/bookshelf', labelKey: 'header.nav.bookshelf' },
]
const navOptions = computed<MenuOption[]>(() => NAV.map(n => ({
  label: () => h(resolveComponent('NuxtLink'), { to: n.to }, () => t(n.labelKey)),
  key: n.to,
})))

const userMenuOptions = computed<DropdownOption[]>(() => [
  { label: t('header.user.profile'), key: 'profile' },
  { label: t('header.user.bookshelf'), key: 'bookshelf' },
  { label: t('header.user.history'), key: 'history' },
  { label: t('header.user.bookmarks'), key: 'bookmarks' },
  { label: t('header.user.notifications'), key: 'notifications' },
  { label: t('header.user.settings'), key: 'settings' },
  ...(authStore.isAdmin ? [{ label: t('header.user.admin'), key: 'admin' }] : []),
  { type: 'divider', key: 'd1' },
  { label: t('common.logout'), key: 'logout' },
])

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
    case 'history':
      router.push('/profile/history')
      break
    case 'bookmarks':
      router.push('/profile/bookmarks')
      break
    case 'notifications':
      router.push('/notifications')
      break
    case 'settings':
      router.push('/profile/settings')
      break
    case 'admin':
      router.push('/admin')
      break
    case 'logout':
      await authStore.logout()
      router.push('/')
      break
  }
}
</script>
