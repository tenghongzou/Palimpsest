<template>
  <div>
    <h2 class="text-lg font-semibold mb-2">忘記密碼</h2>
    <template v-if="!sent">
      <p class="text-sm text-gray-500 mb-4">輸入註冊時使用的電子郵件，我們會寄送重設密碼的連結給你。</p>
      <n-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleSubmit">
        <n-form-item label="電子郵件" path="email">
          <n-input v-model:value="form.email" placeholder="your@email.com" />
        </n-form-item>
        <n-button type="primary" block :loading="loading" attr-type="submit">
          寄送重設連結
        </n-button>
      </n-form>
    </template>
    <n-result v-else status="success" title="請檢查你的信箱" description="如果這個電子郵件已註冊，重設密碼的連結會在幾分鐘內寄達。連結一段時間後會失效。" />
    <div class="text-center mt-4 text-sm">
      <NuxtLink to="/login" class="text-primary">返回登入</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NForm, NFormItem, NInput, NButton, NResult, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'

definePageMeta({ layout: 'auth' })
useHead({ title: '忘記密碼 — Palimpsest' })

const message = useMessage()
const formRef = ref<FormInst | null>(null)
const loading = ref(false)
const sent = ref(false)
const form = reactive({ email: '' })

const rules: FormRules = {
  email: [
    { required: true, message: '請輸入電子郵件', trigger: 'blur' },
    { type: 'email', message: '電子郵件格式不正確', trigger: 'blur' },
  ],
}

async function handleSubmit() {
  await formRef.value?.validate()
  loading.value = true
  try {
    await $fetch('/api/v1/auth/forgot-password', { method: 'POST', body: { email: form.email.trim() } })
    sent.value = true
  }
  catch (e) {
    message.error(describeError(e, { 400: '電子郵件格式不正確' }, '寄送失敗，請稍後再試'))
  }
  finally {
    loading.value = false
  }
}
</script>
