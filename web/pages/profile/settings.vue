<template>
  <div class="max-w-2xl mx-auto space-y-6">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">{{ $t('header.user.settings') }}</h1>
      <n-button text @click="navigateTo('/profile')">{{ $t('profile.backToProfile') }}</n-button>
    </div>

    <n-card :title="$t('settings.avatar.title')">
      <div class="flex items-center gap-6">
        <n-avatar :src="user?.avatar_url || undefined" :size="80" round data-testid="settings-avatar">
          <template v-if="!user?.avatar_url">{{ initial }}</template>
        </n-avatar>
        <div class="space-y-2">
          <input
            ref="fileInput"
            type="file"
            accept="image/jpeg,image/png,image/webp,image/gif"
            class="hidden"
            data-testid="avatar-input"
            @change="handleAvatarChange"
          >
          <n-button :loading="uploading" @click="fileInput?.click()">{{ $t('settings.avatar.change') }}</n-button>
          <div class="text-xs text-gray-400">{{ $t('settings.avatar.hint') }}</div>
        </div>
      </div>
    </n-card>

    <n-card :title="$t('settings.profile.title')">
      <n-form ref="profileFormRef" :model="profileForm" :rules="profileRules" label-placement="left" :label-width="labelWidth">
        <n-form-item :label="$t('auth.username')">
          <span class="text-gray-500">{{ user?.username }}</span>
        </n-form-item>
        <n-form-item :label="$t('auth.email')">
          <span class="text-gray-500">{{ user?.email || '—' }}</span>
        </n-form-item>
        <n-form-item :label="$t('auth.nickname')" path="nickname">
          <n-input v-model:value="profileForm.nickname" maxlength="50" :placeholder="$t('auth.nicknamePlaceholder')" />
        </n-form-item>
        <n-form-item :label="$t('settings.profile.bio')" path="bio">
          <n-input v-model:value="profileForm.bio" type="textarea" :rows="3" maxlength="500" show-count :placeholder="$t('settings.profile.bioPlaceholder')" />
        </n-form-item>
        <n-form-item :label="$t('settings.profile.language')">
          <n-select :value="locale" :options="langOptions" data-testid="settings-language" @update:value="onLanguageChange" />
        </n-form-item>
        <n-button type="primary" :loading="savingProfile" @click="saveProfile">{{ $t('settings.profile.save') }}</n-button>
      </n-form>
    </n-card>

    <n-card :title="$t('reader.toolbar.settings')">
      <template #header-extra>
        <span class="text-xs text-gray-400">{{ $t('settings.reading.hint') }}</span>
      </template>
      <ReaderSettingsForm />
    </n-card>

    <n-card :title="$t('settings.devices.title')">
      <template #header-extra>
        <span class="text-xs text-gray-400">{{ $t('settings.devices.hint') }}</span>
      </template>
      <DeviceList />
    </n-card>

    <n-card :title="$t('settings.password.title')">
      <n-form ref="passwordFormRef" :model="passwordForm" :rules="passwordRules" label-placement="left" :label-width="labelWidth + 16">
        <n-form-item :label="$t('settings.password.current')" path="current">
          <n-input v-model:value="passwordForm.current" type="password" show-password-on="click" :placeholder="$t('settings.password.currentPlaceholder')" />
        </n-form-item>
        <n-form-item :label="$t('auth.newPassword')" path="next">
          <n-input v-model:value="passwordForm.next" type="password" show-password-on="click" :placeholder="$t('auth.passwordPlaceholder')" />
        </n-form-item>
        <n-form-item :label="$t('auth.confirmNewPassword')" path="confirm">
          <n-input v-model:value="passwordForm.confirm" type="password" show-password-on="click" :placeholder="$t('auth.confirmNewPasswordPlaceholder')" />
        </n-form-item>
        <n-button type="warning" :loading="savingPassword" @click="changePassword">{{ $t('settings.password.title') }}</n-button>
      </n-form>
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { NCard, NForm, NFormItem, NInput, NSelect, NButton, NAvatar, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'
import type { User } from '~/types/user'

definePageMeta({ middleware: 'auth' })

const { t } = useI18n()
useHead({ title: () => t('settings.title') })

const MAX_AVATAR_BYTES = 2 * 1024 * 1024

const { locale, options: langOptions, changeLanguage } = useLanguage()
// English labels are longer.
const labelWidth = computed(() => (locale.value === 'en' ? 110 : 80))
const authStore = useAuthStore()
const message = useMessage()
const router = useRouter()

const user = computed(() => authStore.user)
const initial = computed(() => (user.value?.nickname || user.value?.username || '?').slice(0, 1))

const profileFormRef = ref<FormInst | null>(null)
const passwordFormRef = ref<FormInst | null>(null)
const fileInput = ref<HTMLInputElement | null>(null)
const savingProfile = ref(false)
const savingPassword = ref(false)
const uploading = ref(false)

const profileForm = reactive({
  nickname: '',
  bio: '',
})

function fillProfile(u: User | null) {
  profileForm.nickname = u?.nickname || ''
  profileForm.bio = u?.bio || ''
}

const profileRules = computed<FormRules>(() => ({
  nickname: [
    { required: true, message: t('auth.nicknameRequired'), trigger: 'blur' },
    { max: 50, message: t('settings.profile.nicknameMax', { max: 50 }), trigger: 'blur' },
  ],
  bio: { max: 500, message: t('settings.profile.bioMax', { max: 500 }), trigger: 'blur' },
}))

const passwordForm = reactive({ current: '', next: '', confirm: '' })
const passwordRules = computed<FormRules>(() => ({
  current: { required: true, message: t('settings.password.currentRequired'), trigger: 'blur' },
  next: [
    { required: true, message: t('auth.newPasswordRequired'), trigger: 'blur' },
    { min: 8, max: 72, message: t('auth.passwordLength'), trigger: 'blur' },
  ],
  confirm: [
    { required: true, message: t('auth.confirmNewPasswordRequired'), trigger: 'blur' },
    { validator: (_rule: unknown, value: string) => value === passwordForm.next, message: t('auth.passwordMismatch'), trigger: 'blur' },
  ],
}))

/** Applies the language right away and stores it as the account's language_pref. */
async function onLanguageChange(code: string) {
  const result = await changeLanguage(code)
  if (result === 'failed') message.warning(t('language.notSavedToAccount'))
  else message.success(t('language.savedToAccount'))
}

async function saveProfile() {
  await profileFormRef.value?.validate()
  savingProfile.value = true
  try {
    const res = await apiFetch<ApiResponse<User>>('/users/me', {
      method: 'PATCH',
      body: {
        nickname: profileForm.nickname.trim(),
        bio: profileForm.bio,
      },
    })
    authStore.setUser(res.data)
    fillProfile(res.data)
    message.success(t('settings.profile.saved'))
  }
  catch (e) {
    message.error(describeError(t, e, { 400: t('settings.profile.invalid') }, t('settings.profile.saveFailed')))
  }
  finally {
    savingProfile.value = false
  }
}

async function handleAvatarChange(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  if (file.size > MAX_AVATAR_BYTES) {
    message.error(t('settings.avatar.tooLarge', { mb: 2 }))
    return
  }
  uploading.value = true
  try {
    const res = await apiUpload<ApiResponse<User>>('/users/me/avatar', 'avatar', file)
    authStore.setUser(res.data)
    message.success(t('settings.avatar.updated'))
  }
  catch (e) {
    message.error(describeError(t, e, {
      400: t('settings.avatar.unreadable'),
      413: t('settings.avatar.tooLarge', { mb: 2 }),
      415: t('settings.avatar.unsupported'),
      503: t('settings.avatar.storageUnavailable'),
    }, t('settings.avatar.uploadFailed')))
  }
  finally {
    uploading.value = false
  }
}

async function changePassword() {
  await passwordFormRef.value?.validate()
  savingPassword.value = true
  try {
    await apiFetch('/users/me/password', {
      method: 'PUT',
      body: { current_password: passwordForm.current, new_password: passwordForm.next },
    })
    // The change revokes refresh tokens, so start a fresh session.
    message.success(t('settings.password.changed'))
    await authStore.logout()
    router.push('/login')
  }
  catch (e) {
    message.error(describeError(t, e, { 400: t('settings.password.wrongCurrent') }, t('settings.password.failed')))
  }
  finally {
    savingPassword.value = false
  }
}

onMounted(async () => {
  fillProfile(user.value)
  const fresh = await authStore.fetchMe()
  if (fresh) fillProfile(fresh)
  void useReadingSettingsSync().pull()
})
</script>
