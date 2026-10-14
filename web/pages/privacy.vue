<template>
  <article class="max-w-3xl mx-auto space-y-6 leading-relaxed">
    <h1 class="text-2xl font-bold">{{ $t('privacy.title') }}</h1>
    <n-alert type="warning" :show-icon="false">
      {{ $t('privacy.draftNotice') }}
    </n-alert>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('privacy.collected.title') }}</h2>
      <ul class="list-disc pl-6 space-y-1">
        <li v-for="item in COLLECTED" :key="item">
          <strong>{{ $t(`privacy.collected.${item}.label`) }}</strong>{{ $t(`privacy.collected.${item}.text`) }}
        </li>
      </ul>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('privacy.device.title') }}</h2>
      <p>{{ $t('privacy.device.text') }}</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('privacy.thirdParty.title') }}</h2>
      <p>{{ $t('privacy.thirdParty.text') }}</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('privacy.rights.title') }}</h2>
      <p>{{ $t('privacy.rights.text') }}</p>
    </section>
  </article>
</template>

<script setup lang="ts">
import { NAlert } from 'naive-ui'

const COLLECTED = ['account', 'reading', 'community', 'technical'] as const

const { t } = useI18n()
useHead({ title: () => t('privacy.title') })
</script>
