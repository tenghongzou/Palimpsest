<template>
  <div class="space-y-6 max-w-2xl">
    <h1 class="text-xl font-bold">{{ $t('admin.menu.announcements') }}</h1>

    <n-card :title="$t('admin.broadcast.cardTitle')">
      <template #header-extra>
        <span class="text-xs text-gray-400">{{ $t('admin.broadcast.hint') }}</span>
      </template>
      <n-form ref="formRef" :model="form" :rules="rules" label-placement="top">
        <n-form-item :label="$t('admin.columns.title')" path="title">
          <n-input
            v-model:value="form.title"
            maxlength="200"
            show-count
            :placeholder="$t('admin.broadcast.titlePlaceholder')"
            data-testid="broadcast-title"
          />
        </n-form-item>
        <n-form-item :label="$t('admin.broadcast.body')" path="body">
          <n-input
            v-model:value="form.body"
            type="textarea"
            :rows="5"
            maxlength="2000"
            show-count
            :placeholder="$t('admin.broadcast.bodyPlaceholder')"
            data-testid="broadcast-body"
          />
        </n-form-item>
        <div class="flex justify-end">
          <n-button type="primary" :loading="sending" :disabled="!form.title.trim()" data-testid="broadcast-submit" @click="confirmSend">
            {{ $t('admin.broadcast.submit') }}
          </n-button>
        </div>
      </n-form>
    </n-card>

    <n-alert v-if="lastResult" type="success" :title="$t('admin.broadcast.sentTitle')" data-testid="broadcast-result">
      {{ $t('admin.broadcast.sentText', { title: lastResult.title, n: lastResult.recipients, time: dateTime(lastResult.sentAt) }, lastResult.recipients) }}
    </n-alert>
  </div>
</template>

<script setup lang="ts">
import { NAlert, NButton, NCard, NForm, NFormItem, NInput, useDialog, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'

definePageMeta({ middleware: 'admin', layout: 'admin' })

const { t } = useI18n()
const { dateTime } = useAdminLabels()
useHead({ title: () => t('admin.menu.announcements') })

const message = useMessage()
const dialog = useDialog()
const formRef = ref<FormInst | null>(null)
const sending = ref(false)
const form = reactive({ title: '', body: '' })
const lastResult = ref<{ title: string, recipients: number, sentAt: string } | null>(null)

const rules = computed<FormRules>(() => ({
  title: [
    { required: true, whitespace: true, message: t('admin.broadcast.titleRequired'), trigger: 'blur' },
    { max: 200, message: t('admin.broadcast.titleMax', { max: 200 }), trigger: 'blur' },
  ],
  body: { max: 2000, message: t('admin.broadcast.bodyMax', { max: 2000 }), trigger: 'blur' },
}))

async function confirmSend() {
  try {
    await formRef.value?.validate()
  }
  catch {
    return
  }
  const title = form.title.trim()
  dialog.warning({
    title: t('admin.broadcast.confirmTitle'),
    content: t('admin.broadcast.confirmText', { title }),
    positiveText: t('admin.broadcast.send'),
    negativeText: t('common.cancel'),
    onPositiveClick: () => send(),
  })
}

async function send() {
  sending.value = true
  const title = form.title.trim()
  const body = form.body.trim()
  try {
    const res = await apiFetch<ApiResponse<{ recipients: number }>>('/admin/notifications/broadcast', {
      method: 'POST',
      body: { title, ...(body ? { body } : {}) },
    })
    const recipients = res.data?.recipients ?? 0
    lastResult.value = { title, recipients, sentAt: new Date().toISOString() }
    message.success(t('admin.broadcast.sentToast', { n: recipients }, recipients))
    form.title = ''
    form.body = ''
  }
  catch (e) {
    message.error(describeError(t, e, { 400: t('admin.broadcast.invalid') }, t('admin.broadcast.failed')))
  }
  finally {
    sending.value = false
  }
}
</script>
