<template>
  <div class="space-y-6 max-w-2xl">
    <h1 class="text-xl font-bold">系統公告</h1>

    <n-card title="發送系統公告">
      <template #header-extra>
        <span class="text-xs text-gray-400">會以「系統公告」通知所有啟用中的用戶</span>
      </template>
      <n-form ref="formRef" :model="form" :rules="rules" label-placement="top">
        <n-form-item label="標題" path="title">
          <n-input
            v-model:value="form.title"
            maxlength="200"
            show-count
            placeholder="例如：系統維護公告"
            data-testid="broadcast-title"
          />
        </n-form-item>
        <n-form-item label="內容（選填）" path="body">
          <n-input
            v-model:value="form.body"
            type="textarea"
            :rows="5"
            maxlength="2000"
            show-count
            placeholder="公告的詳細內容"
            data-testid="broadcast-body"
          />
        </n-form-item>
        <div class="flex justify-end">
          <n-button type="primary" :loading="sending" :disabled="!form.title.trim()" data-testid="broadcast-submit" @click="confirmSend">
            發送公告
          </n-button>
        </div>
      </n-form>
    </n-card>

    <n-alert v-if="lastResult" type="success" title="公告已發送" data-testid="broadcast-result">
      「{{ lastResult.title }}」已發送給 {{ lastResult.recipients }} 位用戶（{{ adminDateTime(lastResult.sentAt) }}）。
    </n-alert>
  </div>
</template>

<script setup lang="ts">
import { NAlert, NButton, NCard, NForm, NFormItem, NInput, useDialog, useMessage } from 'naive-ui'
import type { FormInst, FormRules } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'

definePageMeta({ middleware: 'admin', layout: 'admin' })
useHead({ title: '系統公告 — 管理後台' })

const message = useMessage()
const dialog = useDialog()
const formRef = ref<FormInst | null>(null)
const sending = ref(false)
const form = reactive({ title: '', body: '' })
const lastResult = ref<{ title: string, recipients: number, sentAt: string } | null>(null)

const rules: FormRules = {
  title: [
    { required: true, whitespace: true, message: '請輸入標題', trigger: 'blur' },
    { max: 200, message: '標題最多 200 字', trigger: 'blur' },
  ],
  body: { max: 2000, message: '內容最多 2000 字', trigger: 'blur' },
}

async function confirmSend() {
  try {
    await formRef.value?.validate()
  }
  catch {
    return
  }
  const title = form.title.trim()
  dialog.warning({
    title: '確認發送公告',
    content: `確定要將「${title}」發送給所有用戶嗎？發送後無法收回。`,
    positiveText: '發送',
    negativeText: '取消',
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
    message.success(`公告已發送給 ${recipients} 位用戶`)
    form.title = ''
    form.body = ''
  }
  catch (e) {
    message.error(describeError(e, { 400: '標題或內容不正確（標題最多 200 字、內容最多 2000 字）' }, '發送失敗，請稍後再試'))
  }
  finally {
    sending.value = false
  }
}
</script>
