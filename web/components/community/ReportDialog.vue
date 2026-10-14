<template>
  <n-modal
    :show="show"
    preset="card"
    :title="$t('community.report.title')"
    style="max-width: 420px"
    :mask-closable="!submitting"
    @update:show="emit('update:show', $event)"
  >
    <n-form label-placement="top">
      <n-form-item :label="$t('community.report.reason')">
        <n-radio-group v-model:value="reason" name="report-reason">
          <div class="grid grid-cols-2 gap-2">
            <n-radio v-for="r in REPORT_REASONS" :key="r" :value="r" :label="$t(`community.report.reasons.${r}`)" />
          </div>
        </n-radio-group>
      </n-form-item>
      <n-form-item :label="$t('community.report.description')">
        <n-input v-model:value="description" type="textarea" :rows="3" maxlength="1000" show-count :placeholder="$t('community.report.descriptionPlaceholder')" />
      </n-form-item>
    </n-form>
    <template #footer>
      <div class="flex justify-end gap-2">
        <n-button :disabled="submitting" @click="emit('update:show', false)">{{ $t('common.cancel') }}</n-button>
        <n-button type="error" :loading="submitting" :disabled="!reason" data-testid="report-submit" @click="submit">{{ $t('community.report.submit') }}</n-button>
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

const { t } = useI18n()
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
    message.success(t('community.report.submitted'))
    emit('reported')
    emit('update:show', false)
  }
  catch (e) {
    message.error(describeError(t, e, { 401: t('auth.loginFirst'), 404: t('community.report.notFound') }, t('community.report.failed')))
  }
  finally {
    submitting.value = false
  }
}
</script>
