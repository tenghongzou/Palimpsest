<template>
  <div class="max-w-2xl mx-auto space-y-6">
    <h1 class="text-xl font-bold">帳號設定</h1>

    <n-card title="個人資料">
      <n-form :model="profileForm" label-placement="left" label-width="80">
        <n-form-item label="暱稱">
          <n-input v-model:value="profileForm.nickname" />
        </n-form-item>
        <n-form-item label="個人簡介">
          <n-input v-model:value="profileForm.bio" type="textarea" :rows="3" />
        </n-form-item>
        <n-form-item label="語言偏好">
          <n-select v-model:value="profileForm.language_pref" :options="langOptions" />
        </n-form-item>
        <n-button type="primary" @click="saveProfile">儲存</n-button>
      </n-form>
    </n-card>

    <n-card title="閱讀設定">
      <n-form label-placement="left" label-width="80">
        <n-form-item label="字體大小">
          <n-slider v-model:value="readerSettings.fontSize" :min="12" :max="32" :step="1" />
        </n-form-item>
        <n-form-item label="行高">
          <n-slider v-model:value="readerSettings.lineHeight" :min="1.2" :max="3" :step="0.1" />
        </n-form-item>
        <n-form-item label="閱讀主題">
          <n-select
            v-model:value="readerSettings.theme"
            :options="[
              { label: '白色', value: 'white' },
              { label: '米黃', value: 'yellow' },
              { label: '護眼綠', value: 'green' },
              { label: '暗色', value: 'dark' },
              { label: '黑色', value: 'black' },
            ]"
          />
        </n-form-item>
        <n-button @click="readerStore.resetSettings()">重置為預設</n-button>
      </n-form>
    </n-card>
  </div>
</template>

<script setup lang="ts">
import { NCard, NForm, NFormItem, NInput, NSelect, NSlider, NButton, useMessage } from 'naive-ui'

definePageMeta({ middleware: 'auth' })
useHead({ title: '設定 — Palimpsest' })

const authStore = useAuthStore()
const readerStore = useReaderStore()
const message = useMessage()

const user = computed(() => authStore.user)
const readerSettings = reactive({ ...readerStore.settings })

watch(readerSettings, (val) => {
  readerStore.updateSettings(val)
}, { deep: true })

const profileForm = reactive({
  nickname: user.value?.nickname || '',
  bio: user.value?.bio || '',
  language_pref: user.value?.language_pref || 'zh-TW',
})

const langOptions = [
  { label: '繁體中文', value: 'zh-TW' },
  { label: '简体中文', value: 'zh-CN' },
  { label: 'English', value: 'en' },
]

async function saveProfile() {
  try {
    await $fetch('/api/v1/user/profile', {
      method: 'PUT',
      headers: { Authorization: `Bearer ${authStore.accessToken}` },
      body: profileForm,
    })
    message.success('已儲存')
  }
  catch {
    message.error('儲存失敗')
  }
}
</script>
