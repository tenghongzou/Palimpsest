<template>
  <n-modal
    :show="show"
    preset="card"
    title="檢舉內容"
    style="max-width: 420px"
    :mask-closable="!submitting"
    @update:show="emit('update:show', $event)"
  >
    <n-form label-placement="top">
      <n-form-item label="原因">
        <n-radio-group v-model:value="reason" name="report-reason">
          <div class="grid grid-cols-2 gap-2">
            <n-radio v-for="r in REPORT_REASONS" :key="r.value" :value="r.value" :label="r.label" />
          </div>
        </n-radio-group>
      </n-form-item>
      <n-form-item label="補充說明（選填）">
        <n-input v-model:value="description" type="textarea" :rows="3" maxlength="1000" show-count placeholder="描述問題，協助管理員判斷" />
      </n-form-item>
    </n-form>
    <template #footer>
      <div class="flex justify-end gap-2">
        <n-button :disabled="submitting" @click="emit('update:show', false)">取消</n-button>
        <n-button type="error" :loading="submitting" :disabled="!reason" data-testid="report-submit" @click="submit">送出檢舉</n-button>
      </div>
    </template>
  </n-modal>
</template>

<script setup lang="ts">
import { NModal, NForm, NFormItem, NRadioGroup, NRadio, NInput, NButton, useMessage } from 'naive-ui'
import { REPORT_REASONS, type ReportReason, type ReportTargetType } from '~/types/models'

const props = defineProps<{
  show: boolean
  targetType: ReportTargetType
  targetId: string | null
}>()

const emit = defineEmits<{
  'update:show': [value: boolean]
  'reported': []
}>()

const message = useMessage()
const reason = ref<ReportReason | null>(null)
const description = ref('')
const submitting = ref(false)

watch(() => props.show, (open) => {
  if (open) {
    reason.value = null
    description.value = ''
  }
})

async function submit() {
  if (!reason.value || !props.targetId) return
  submitting.value = true
  try {
    await submitReport({
      target_type: props.targetType,
      target_id: props.targetId,
      reason: reason.value,
      ...(description.value.trim() ? { description: description.value.trim() } : {}),
    })
    message.success('已送出檢舉，感謝你的回報')
    emit('reported')
    emit('update:show', false)
  }
  catch (e) {
    message.error(describeError(e, { 401: '請先登入', 404: '找不到這則內容' }, '檢舉失敗，請稍後再試'))
  }
  finally {
    submitting.value = false
  }
}
</script>
