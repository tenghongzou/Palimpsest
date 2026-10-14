<template>
  <div>
    <h2 class="text-lg font-semibold mb-2">{{ $t('auth.forgot.title') }}</h2>
    <template v-if="!sent">
      <p class="text-sm text-gray-500 mb-4">{{ $t('auth.forgot.intro') }}</p>
      <n-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleSubmit">
        <n-form-item :label="$t('auth.email')" path="email">
          <n-input v-model:value="form.email" placeholder="your@email.com" />
        </n-form-item>
        <n-button type="primary" block :loading="loading" attr-type="submit">
          {{ $t('auth.forgot.submit') }}
        </n-button>
      </n-form>
    </template>
    <n-result v-else status="success" :title="$t('auth.forgot.sentTitle')" :description="$t('auth.forgot.sentText')" />
    <div class="text-center mt-4 text-sm">
      <NuxtLink to="/login" class="text-primary">{{ $t('auth.backToLogin') }}</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NForm, NFormItem, NInput, NButton, NResult, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'

definePageMeta({ layout: 'auth' })

const { t } = useI18n()
useHead({ title: () => t('auth.forgot.title') })

const message = useMessage()
const formRef = ref<FormInst | null>(null)
const loading = ref(false)
const sent = ref(false)
const form = reactive({ email: '' })

const rules = computed<FormRules>(() => ({
  email: [
    { required: true, message: t('auth.emailRequired'), trigger: 'blur' },
    { type: 'email', message: t('auth.emailInvalid'), trigger: 'blur' },
  ],
}))

async function handleSubmit() {
  await formRef.value?.validate()
  loading.value = true
  try {
    await $fetch('/api/v1/auth/forgot-password', { method: 'POST', body: { email: form.email.trim() } })
    sent.value = true
  }
  catch (e) {
    message.error(describeError(t, e, { 400: t('auth.emailInvalid') }, t('auth.forgot.failed')))
  }
  finally {
    loading.value = false
  }
}
</script>
