<template>
  <div>
    <n-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleRegister">
      <n-form-item label="帳號" path="username">
        <n-input v-model:value="form.username" placeholder="4-20 個字元" />
      </n-form-item>
      <n-form-item label="暱稱" path="nickname">
        <n-input v-model:value="form.nickname" placeholder="顯示名稱" />
      </n-form-item>
      <n-form-item label="電子郵件" path="email">
        <n-input v-model:value="form.email" placeholder="your@email.com" />
      </n-form-item>
      <n-form-item label="密碼" path="password">
        <n-input v-model:value="form.password" type="password" show-password-on="click" placeholder="至少 8 個字元" />
      </n-form-item>
      <n-form-item label="確認密碼" path="confirmPassword">
        <n-input v-model:value="form.confirmPassword" type="password" show-password-on="click" placeholder="再次輸入密碼" />
      </n-form-item>
      <n-button type="primary" block :loading="loading" attr-type="submit">
        註冊
      </n-button>
    </n-form>
    <div class="text-center mt-4 text-sm">
      已有帳號？
      <NuxtLink to="/login" class="text-primary">立即登入</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NForm, NFormItem, NInput, NButton, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'

definePageMeta({ layout: 'auth' })
useHead({ title: '註冊 — Palimpsest' })

const router = useRouter()
const authStore = useAuthStore()
const message = useMessage()

const formRef = ref<FormInst | null>(null)
const loading = ref(false)

const form = reactive({
  username: '',
  nickname: '',
  email: '',
  password: '',
  confirmPassword: '',
})

const rules: FormRules = {
  username: [
    { required: true, message: '請輸入帳號', trigger: 'blur' },
    { min: 4, max: 20, message: '帳號需 4-20 個字元', trigger: 'blur' },
  ],
  nickname: { required: true, message: '請輸入暱稱', trigger: 'blur' },
  email: [
    { required: true, message: '請輸入電子郵件', trigger: 'blur' },
    { type: 'email', message: '電子郵件格式不正確', trigger: 'blur' },
  ],
  password: [
    { required: true, message: '請輸入密碼', trigger: 'blur' },
    { min: 8, message: '密碼至少 8 個字元', trigger: 'blur' },
  ],
  confirmPassword: [
    { required: true, message: '請再次輸入密碼', trigger: 'blur' },
    {
      validator: (_rule: any, value: string) => value === form.password,
      message: '兩次輸入的密碼不一致',
      trigger: 'blur',
    },
  ],
}

async function handleRegister() {
  await formRef.value?.validate()
  loading.value = true
  try {
    await authStore.register({
      username: form.username,
      email: form.email,
      password: form.password,
      nickname: form.nickname,
    })
    message.success('註冊成功')
    router.push('/')
  }
  catch (e: any) {
    message.error(e?.data?.message || '註冊失敗，請稍後再試')
  }
  finally {
    loading.value = false
  }
}
</script>
