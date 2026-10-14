<template>
  <div>
    <h2 class="text-lg font-semibold mb-4">重設密碼</h2>
    <n-alert v-if="!token" type="error" class="mb-4" data-testid="reset-error">
      重設連結不完整，請重新申請。
    </n-alert>
    <n-result v-else-if="done" status="success" title="密碼已重設" description="請使用新密碼登入。">
      <template #footer>
        <n-button type="primary" @click="navigateTo('/login')">前往登入</n-button>
      </template>
    </n-result>
    <template v-else>
      <n-alert v-if="errorText" type="error" class="mb-4" data-testid="reset-error">
        {{ errorText }}
        <NuxtLink to="/forgot-password" class="text-primary ml-1">重新申請</NuxtLink>
      </n-alert>
      <n-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleSubmit">
        <n-form-item label="新密碼" path="password">
          <n-input v-model:value="form.password" type="password" show-password-on="click" placeholder="至少 8 個字元" />
        </n-form-item>
        <n-form-item label="確認新密碼" path="confirm">
          <n-input v-model:value="form.confirm" type="password" show-password-on="click" placeholder="再次輸入新密碼" />
        </n-form-item>
        <n-button type="primary" block :loading="loading" attr-type="submit">重設密碼</n-button>
      </n-form>
    </template>
    <div class="text-center mt-4 text-sm">
      <NuxtLink to="/login" class="text-primary">返回登入</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NForm, NFormItem, NInput, NButton, NAlert, NResult } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'

definePageMeta({ layout: 'auth' })
useHead({ title: '重設密碼 — Palimpsest' })

const route = useRoute()
const token = computed(() => (route.query.token as string) || '')
const formRef = ref<FormInst | null>(null)
const loading = ref(false)
const done = ref(false)
const errorText = ref('')
const form = reactive({ password: '', confirm: '' })

const rules: FormRules = {
  password: [
    { required: true, message: '請輸入新密碼', trigger: 'blur' },
    { min: 8, max: 72, message: '密碼需 8-72 個字元', trigger: 'blur' },
  ],
  confirm: [
    { required: true, message: '請再次輸入新密碼', trigger: 'blur' },
    { validator: (_rule: unknown, value: string) => value === form.password, message: '兩次輸入的密碼不一致', trigger: 'blur' },
  ],
}

async function handleSubmit() {
  await formRef.value?.validate()
  loading.value = true
  errorText.value = ''
  try {
    await $fetch('/api/v1/auth/reset-password', {
      method: 'POST',
      body: { token: token.value, new_password: form.password },
    })
    done.value = true
  }
  catch (e) {
    errorText.value = describeError(e, { 400: '重設連結無效或已過期。' }, '重設失敗，請稍後再試。')
  }
  finally {
    loading.value = false
  }
}
</script>
