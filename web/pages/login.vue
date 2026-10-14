<template>
  <div>
    <n-form ref="formRef" :model="form" :rules="rules" @submit.prevent="handleLogin">
      <n-form-item :label="$t('auth.login.loginLabel')" path="login">
        <n-input v-model:value="form.login" :placeholder="$t('auth.login.loginPlaceholder')" />
      </n-form-item>
      <n-form-item :label="$t('auth.password')" path="password">
        <n-input v-model:value="form.password" type="password" show-password-on="click" :placeholder="$t('auth.login.passwordPlaceholder')" />
      </n-form-item>
      <div class="flex justify-end -mt-2 mb-3 text-sm">
        <NuxtLink to="/forgot-password" class="text-primary">{{ $t('auth.login.forgot') }}</NuxtLink>
      </div>
      <n-button type="primary" block :loading="loading" attr-type="submit">
        {{ $t('common.login') }}
      </n-button>
    </n-form>
    <div class="text-center mt-4 text-sm">
      {{ $t('auth.login.noAccount') }}
      <NuxtLink to="/register" class="text-primary">{{ $t('auth.login.registerNow') }}</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { NForm, NFormItem, NInput, NButton, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'

definePageMeta({ layout: 'auth' })

const { t } = useI18n()
useHead({ title: () => t('common.login') })

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

const rules = computed<FormRules>(() => ({
  login: { required: true, message: t('auth.login.loginRequired'), trigger: 'blur' },
  password: { required: true, message: t('auth.passwordRequired'), trigger: 'blur' },
}))

async function handleLogin() {
  await formRef.value?.validate()
  loading.value = true
  try {
    await authStore.login({ login: form.login, password: form.password })
    message.success(t('auth.login.success'))
    const redirect = route.query.redirect as string
    // Only follow same-site paths.
    router.push(redirect && redirect.startsWith('/') && !redirect.startsWith('//') ? redirect : '/')
  }
  catch (e) {
    message.error(describeError(t, e, {
      400: t('auth.login.missing'),
      401: t('auth.login.invalid'),
      403: t('auth.login.banned'),
    }, t('auth.login.failed')))
  }
  finally {
    loading.value = false
  }
}
</script>
