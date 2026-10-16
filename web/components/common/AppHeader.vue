<template>
  <!-- From md up: logo, nav menu, search box, language, account. Below md the nav
       and language switch move into a drawer and search becomes an icon link. -->
  <div class="flex items-center justify-between w-full gap-2">
    <div class="flex items-center gap-6 min-w-0">
      <!-- The logo's aria-label ("Palimpsest") names the link. -->
      <NuxtLink to="/" class="brand-link flex items-center shrink-0" data-testid="brand-home">
        <BrandLogo variant="horizontal" :height="30" class="hidden md:block" />
        <BrandLogo variant="mark" :height="30" class="md:hidden" />
      </NuxtLink>
      <div class="hidden md:block">
        <n-menu
          mode="horizontal"
          :options="navOptions"
          :value="activeNav"
          @update:value="handleNavSelect"
        />
      </div>
    </div>

    <div class="flex items-center gap-2 md:gap-4 shrink-0">
      <div class="hidden md:block">
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
      </div>
      <div class="flex md:hidden">
        <NuxtLink
          to="/search"
          class="header-icon-link"
          :aria-label="$t('header.search')"
          :title="$t('header.search')"
          data-testid="header-search-link"
        >
          <n-icon :component="SearchIcon" :size="22" aria-hidden="true" />
        </NuxtLink>
      </div>

      <div class="hidden md:block">
        <LanguageSwitcher />
      </div>

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
        <div class="hidden md:block">
          <n-button size="small" type="primary" @click="navigateTo('/register')">{{ $t('common.register') }}</n-button>
        </div>
      </template>

      <div class="flex md:hidden">
        <n-button
          quaternary
          circle
          :aria-label="$t('header.openMenu')"
          :title="$t('header.openMenu')"
          aria-haspopup="dialog"
          :aria-expanded="drawerOpen"
          data-testid="header-menu-button"
          @click="drawerOpen = true"
        >
          <template #icon>
            <n-icon :component="MenuIcon" :size="22" />
          </template>
        </n-button>
      </div>
    </div>

    <n-drawer v-model:show="drawerOpen" placement="right" :width="272" :auto-focus="false">
      <n-drawer-content :title="$t('header.menu')" closable body-content-style="padding: 8px 0;">
        <nav :aria-label="$t('header.mainNav')" data-testid="header-drawer-nav">
          <NuxtLink
            v-for="n in NAV"
            :key="n.to"
            :to="n.to"
            class="drawer-link"
            :class="{ 'drawer-link--active': activeNav === n.to }"
            :aria-current="activeNav === n.to ? 'page' : undefined"
          >
            {{ $t(n.labelKey) }}
          </NuxtLink>
        </nav>
        <div class="drawer-section">
          <LanguageSwitcher />
        </div>
        <div v-if="!isLoggedIn" class="drawer-section flex gap-2">
          <n-button class="flex-1" @click="navigateTo('/login')">{{ $t('common.login') }}</n-button>
          <n-button class="flex-1" type="primary" @click="navigateTo('/register')">{{ $t('common.register') }}</n-button>
        </div>
      </n-drawer-content>
    </n-drawer>
  </div>
</template>

<script setup lang="ts">
import {
  NMenu, NInput, NIcon, NButton, NDropdown, NAvatar, NDrawer, NDrawerContent,
} from 'naive-ui'
import type { MenuOption, DropdownOption } from 'naive-ui'
import { Search as SearchIcon, Person as PersonIcon, Menu as MenuIcon } from '@vicons/ionicons5'
import { h } from 'vue'

const { t } = useI18n()
const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const isLoggedIn = computed(() => authStore.isLoggedIn)
const user = computed(() => authStore.user)

const searchQuery = ref('')

// Mobile navigation drawer; closes once a link inside it changes the route.
const drawerOpen = ref(false)
watch(() => route.fullPath, () => {
  drawerOpen.value = false
})

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

<style scoped>
.brand-link:hover,
.header-icon-link:hover,
.drawer-link:hover {
  text-decoration: none;
}

.header-icon-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  color: inherit;
}

.drawer-link {
  display: block;
  padding: 12px 24px;
  font-size: 16px;
  color: inherit;
}

.drawer-link--active {
  color: var(--color-primary);
  background: rgba(24, 144, 255, 0.08);
  font-weight: 600;
}

.drawer-section {
  padding: 12px 24px;
  border-top: 1px solid #efeff5;
  margin-top: 8px;
}
</style>
