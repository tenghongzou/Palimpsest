<template>
  <div>
    <h2 class="text-lg font-semibold mb-4">{{ $t('auth.reset.title') }}</h2>
    <n-alert v-if="!token" type="error" class="mb-4" data-testid="reset-error">
      {{ $t('auth.reset.incomplete') }}
    </n-alert>
    <n-result v-else-if="done" status="success" :title="$t('auth.reset.doneTitle')" :description="$t('auth.reset.doneText')">
      <template #footer>
        <n-button type="primary" @click="navigateTo('/login')">{{ $t('auth.reset.goLogin') }}</n-button>
      </template>
    </n-result>
    <template v-else>
      <n-alert v-if="errorText" type="error" class="mb-4" data-testid="reset-error">
        {{ errorText }}
        <NuxtLink to="/forgot-password" class="text-primary ml-1">{{ $t('auth.reset.requestAgain') }}</NuxtLink>
      </n-alert>
      <n-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleSubmit">
        <n-form-item :label="$t('auth.newPassword')" path="password">
          <n-input v-model:value="form.password" type="password" show-password-on="click" :placeholder="$t('auth.passwordPlaceholder')" />
        </n-form-item>
        <n-form-item :label="$t('auth.confirmNewPassword')" path="confirm">
          <n-input v-model:value="form.confirm" type="password" show-password-on="click" :placeholder="$t('auth.confirmNewPasswordPlaceholder')" />
        </n-form-item>
        <n-button type="primary" block :loading="loading" attr-type="submit">{{ $t('auth.reset.title') }}</n-button>
      </n-form>
    </template>
    <div class="text-center mt-4 text-sm">
      <NuxtLink to="/login" class="text-primary">{{ $t('auth.backToLogin') }}</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NForm, NFormItem, NInput, NButton, NAlert, NResult } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'

definePageMeta({ layout: 'auth' })

const { t } = useI18n()
useHead({ title: () => t('auth.reset.title') })

const route = useRoute()
const token = computed(() => (route.query.token as string) || '')
const formRef = ref<FormInst | null>(null)
const loading = ref(false)
const done = ref(false)
const errorText = ref('')
const form = reactive({ password: '', confirm: '' })

const rules = computed<FormRules>(() => ({
  password: [
    { required: true, message: t('auth.newPasswordRequired'), trigger: 'blur' },
    { min: 8, max: 72, message: t('auth.passwordLength'), trigger: 'blur' },
  ],
  confirm: [
    { required: true, message: t('auth.confirmNewPasswordRequired'), trigger: 'blur' },
    { validator: (_rule: unknown, value: string) => value === form.password, message: t('auth.passwordMismatch'), trigger: 'blur' },
  ],
}))

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
    errorText.value = describeError(t, e, { 400: t('auth.reset.invalidLink') }, t('auth.reset.failed'))
  }
  finally {
    loading.value = false
  }
}
</script>
