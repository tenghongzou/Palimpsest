<template>
  <div>
    <n-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleRegister">
      <n-form-item :label="$t('auth.username')" path="username">
        <n-input v-model:value="form.username" :placeholder="$t('auth.register.usernamePlaceholder')" />
      </n-form-item>
      <n-form-item :label="$t('auth.nickname')" path="nickname">
        <n-input v-model:value="form.nickname" :placeholder="$t('auth.nicknamePlaceholder')" />
      </n-form-item>
      <n-form-item :label="$t('auth.email')" path="email">
        <n-input v-model:value="form.email" placeholder="your@email.com" />
      </n-form-item>
      <n-form-item :label="$t('auth.password')" path="password">
        <n-input v-model:value="form.password" type="password" show-password-on="click" :placeholder="$t('auth.passwordPlaceholder')" />
      </n-form-item>
      <n-form-item :label="$t('auth.register.confirmPassword')" path="confirmPassword">
        <n-input v-model:value="form.confirmPassword" type="password" show-password-on="click" :placeholder="$t('auth.register.confirmPlaceholder')" />
      </n-form-item>
      <n-button type="primary" block :loading="loading" attr-type="submit">
        {{ $t('common.register') }}
      </n-button>
    </n-form>
    <div class="text-center mt-4 text-sm">
      {{ $t('auth.register.haveAccount') }}
      <NuxtLink to="/login" class="text-primary">{{ $t('auth.register.loginNow') }}</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NForm, NFormItem, NInput, NButton, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'

definePageMeta({ layout: 'auth' })

const { t } = useI18n()
useHead({ title: () => t('common.register') })

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

const rules = computed<FormRules>(() => ({
  username: [
    { required: true, message: t('auth.register.usernameRequired'), trigger: 'blur' },
    { min: 4, max: 20, message: t('auth.register.usernameLength'), trigger: 'blur' },
  ],
  nickname: { required: true, message: t('auth.nicknameRequired'), trigger: 'blur' },
  email: [
    { required: true, message: t('auth.emailRequired'), trigger: 'blur' },
    { type: 'email', message: t('auth.emailInvalid'), trigger: 'blur' },
  ],
  password: [
    { required: true, message: t('auth.passwordRequired'), trigger: 'blur' },
    { min: 8, message: t('auth.register.passwordMin'), trigger: 'blur' },
  ],
  confirmPassword: [
    { required: true, message: t('auth.register.confirmRequired'), trigger: 'blur' },
    {
      validator: (_rule: unknown, value: string) => value === form.password,
      message: t('auth.passwordMismatch'),
      trigger: 'blur',
    },
  ],
}))

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
    message.success(t('auth.register.success'))
    router.push('/')
  }
  catch (e) {
    message.error(describeError(t, e, { 400: t('auth.register.invalid'), 409: t('auth.register.taken') }, t('auth.register.failed')))
  }
  finally {
    loading.value = false
  }
}
</script>
