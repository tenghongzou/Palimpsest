<template>
  <div>
    <n-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleLogin">
      <n-form-item label="帳號 / 電子郵件" path="login">
        <n-input v-model:value="form.login" placeholder="輸入帳號或電子郵件" />
      </n-form-item>
      <n-form-item label="密碼" path="password">
        <n-input v-model:value="form.password" type="password" show-password-on="click" placeholder="輸入密碼" />
      </n-form-item>
      <div class="flex justify-end -mt-2 mb-3 text-sm">
        <NuxtLink to="/forgot-password" class="text-primary">忘記密碼？</NuxtLink>
      </div>
      <n-button type="primary" block :loading="loading" attr-type="submit">
        登入
      </n-button>
    </n-form>
    <div class="text-center mt-4 text-sm">
      還沒有帳號？
      <NuxtLink to="/register" class="text-primary">立即註冊</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NForm, NFormItem, NInput, NButton, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'

definePageMeta({ layout: 'auth' })
useHead({ title: '登入 — Palimpsest' })

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const message = useMessage()

const formRef = ref<FormInst | null>(null)
const loading = ref(false)

const form = reactive({
  login: '',
  password: '',
})

const rules: FormRules = {
  login: { required: true, message: '請輸入帳號或電子郵件', trigger: 'blur' },
  password: { required: true, message: '請輸入密碼', trigger: 'blur' },
}

async function handleLogin() {
  await formRef.value?.validate()
  loading.value = true
  try {
    await authStore.login({ login: form.login, password: form.password })
    message.success('登入成功')
    const redirect = route.query.redirect as string
    // Only follow same-site paths.
    router.push(redirect && redirect.startsWith('/') && !redirect.startsWith('//') ? redirect : '/')
  }
  catch (e) {
    message.error(describeError(e, { 400: '請輸入帳號與密碼', 401: '帳號或密碼錯誤', 403: '此帳號已被停權' }, '登入失敗，請稍後再試'))
  }
  finally {
    loading.value = false
  }
}
</script>
