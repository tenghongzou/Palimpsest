<template>
  <div class="max-w-2xl mx-auto space-y-6">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold">帳號設定</h1>
      <n-button text @click="navigateTo('/profile')">返回個人中心</n-button>
    </div>

    <n-card title="頭像">
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
          <n-button :loading="uploading" @click="fileInput?.click()">更換頭像</n-button>
          <div class="text-xs text-gray-400">支援 JPEG、PNG、WebP、GIF，檔案不超過 2 MB</div>
        </div>
      </div>
    </n-card>

    <n-card title="個人資料">
      <n-form ref="profileFormRef" :model="profileForm" :rules="profileRules" label-placement="left" label-width="80">
        <n-form-item label="帳號">
          <span class="text-gray-500">{{ user?.username }}</span>
        </n-form-item>
        <n-form-item label="電子郵件">
          <span class="text-gray-500">{{ user?.email || '—' }}</span>
        </n-form-item>
        <n-form-item label="暱稱" path="nickname">
          <n-input v-model:value="profileForm.nickname" maxlength="50" placeholder="顯示名稱" />
        </n-form-item>
        <n-form-item label="個人簡介" path="bio">
          <n-input v-model:value="profileForm.bio" type="textarea" :rows="3" maxlength="500" show-count placeholder="介紹一下自己" />
        </n-form-item>
        <n-form-item label="語言偏好" path="language_pref">
          <n-select v-model:value="profileForm.language_pref" :options="langOptions" />
        </n-form-item>
        <n-button type="primary" :loading="savingProfile" @click="saveProfile">儲存個人資料</n-button>
      </n-form>
    </n-card>

    <n-card title="閱讀設定">
      <template #header-extra>
        <span class="text-xs text-gray-400">變更會自動同步到你的帳號</span>
      </template>
      <ReaderSettingsForm />
    </n-card>

    <n-card title="登入裝置">
      <template #header-extra>
        <span class="text-xs text-gray-400">登入過你帳號的瀏覽器與 App</span>
      </template>
      <DeviceList />
    </n-card>

    <n-card title="變更密碼">
      <n-form ref="passwordFormRef" :model="passwordForm" :rules="passwordRules" label-placement="left" label-width="96">
        <n-form-item label="目前密碼" path="current">
          <n-input v-model:value="passwordForm.current" type="password" show-password-on="click" placeholder="目前的密碼" />
        </n-form-item>
        <n-form-item label="新密碼" path="next">
          <n-input v-model:value="passwordForm.next" type="password" show-password-on="click" placeholder="至少 8 個字元" />
        </n-form-item>
        <n-form-item label="確認新密碼" path="confirm">
          <n-input v-model:value="passwordForm.confirm" type="password" show-password-on="click" placeholder="再次輸入新密碼" />
        </n-form-item>
        <n-button type="warning" :loading="savingPassword" @click="changePassword">變更密碼</n-button>
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
useHead({ title: '設定 — Palimpsest' })

const MAX_AVATAR_BYTES = 2 * 1024 * 1024

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
  language_pref: 'zh-TW' as User['language_pref'],
})

function fillProfile(u: User | null) {
  profileForm.nickname = u?.nickname || ''
  profileForm.bio = u?.bio || ''
  profileForm.language_pref = u?.language_pref || 'zh-TW'
}

const profileRules: FormRules = {
  nickname: [
    { required: true, message: '請輸入暱稱', trigger: 'blur' },
    { max: 50, message: '暱稱最多 50 個字元', trigger: 'blur' },
  ],
  bio: { max: 500, message: '簡介最多 500 個字元', trigger: 'blur' },
}

const passwordForm = reactive({ current: '', next: '', confirm: '' })
const passwordRules: FormRules = {
  current: { required: true, message: '請輸入目前密碼', trigger: 'blur' },
  next: [
    { required: true, message: '請輸入新密碼', trigger: 'blur' },
    { min: 8, max: 72, message: '密碼需 8-72 個字元', trigger: 'blur' },
  ],
  confirm: [
    { required: true, message: '請再次輸入新密碼', trigger: 'blur' },
    { validator: (_rule: unknown, value: string) => value === passwordForm.next, message: '兩次輸入的密碼不一致', trigger: 'blur' },
  ],
}

const langOptions = [
  { label: '繁體中文', value: 'zh-TW' },
  { label: '简体中文', value: 'zh-CN' },
  { label: 'English', value: 'en' },
]

async function saveProfile() {
  await profileFormRef.value?.validate()
  savingProfile.value = true
  try {
    const res = await apiFetch<ApiResponse<User>>('/users/me', {
      method: 'PATCH',
      body: {
        nickname: profileForm.nickname.trim(),
        bio: profileForm.bio,
        language_pref: profileForm.language_pref,
      },
    })
    authStore.setUser(res.data)
    fillProfile(res.data)
    message.success('個人資料已儲存')
  }
  catch (e) {
    message.error(describeError(e, { 400: '資料格式不正確' }, '儲存失敗，請稍後再試'))
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
    message.error('圖片超過 2 MB，請選擇較小的檔案')
    return
  }
  uploading.value = true
  try {
    const res = await apiUpload<ApiResponse<User>>('/users/me/avatar', 'avatar', file)
    authStore.setUser(res.data)
    message.success('頭像已更新')
  }
  catch (e) {
    message.error(describeError(e, {
      400: '無法讀取這個圖片檔',
      413: '圖片超過 2 MB，請選擇較小的檔案',
      415: '只支援 JPEG、PNG、WebP 或 GIF 圖片',
      503: '圖片儲存服務暫時無法使用，請稍後再試',
    }, '上傳失敗，請稍後再試'))
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
    message.success('密碼已變更，請使用新密碼重新登入')
    await authStore.logout()
    router.push('/login')
  }
  catch (e) {
    message.error(describeError(e, { 400: '目前密碼不正確' }, '變更失敗，請稍後再試'))
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
