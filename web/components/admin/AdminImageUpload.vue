<template>
  <div class="w-full space-y-2">
    <div class="flex gap-2">
      <n-input
        :value="modelValue"
        :placeholder="$t('admin.image.urlPlaceholder')"
        clearable
        @update:value="emit('update:modelValue', $event ?? '')"
      />
      <n-button :loading="uploading" @click="fileInput?.click()">{{ $t('admin.image.upload') }}</n-button>
      <input
        ref="fileInput"
        type="file"
        accept="image/jpeg,image/png,image/webp,image/gif"
        class="hidden"
        data-testid="admin-image-file"
        @change="handleFile"
      >
    </div>
    <img v-if="modelValue" :src="modelValue" :alt="$t('admin.image.preview')" class="max-h-40 rounded border">
  </div>
</template>

<script setup lang="ts">
import { NInput, NButton, useMessage } from 'naive-ui'
import type { ApiResponse } from '~/utils/api'

const props = defineProps<{
  modelValue: string
  kind: 'covers' | 'banners'
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const { t } = useI18n()
const message = useMessage()
const fileInput = ref<HTMLInputElement | null>(null)
const uploading = ref(false)

const MAX_BYTES = 5 * 1024 * 1024

async function handleFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  if (file.size > MAX_BYTES) {
    message.error(t('admin.image.tooLarge', { mb: 5 }))
    return
  }
  uploading.value = true
  try {
    const res = await apiUpload<ApiResponse<{ url: string }>>('/admin/uploads', 'file', file, {
      params: { kind: props.kind },
    })
    emit('update:modelValue', res.data.url)
    message.success(t('admin.image.uploaded'))
  }
  catch (error) {
    message.error(uploadErrorMessage(t, error))
  }
  finally {
    uploading.value = false
  }
}
</script>
