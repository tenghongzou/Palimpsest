<template>
  <article class="max-w-3xl mx-auto space-y-6 leading-relaxed">
    <h1 class="text-2xl font-bold">{{ $t('terms.title') }}</h1>
    <n-alert type="warning" :show-icon="false">
      {{ $t('terms.draftNotice') }}
    </n-alert>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('terms.account.title') }}</h2>
      <p>{{ $t('terms.account.text') }}</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('terms.userContent.title') }}</h2>
      <p>{{ $t('terms.userContent.text') }}</p>
      <p>{{ $t('terms.userContent.moderation') }}</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('terms.copyright.title') }}</h2>
      <p>{{ $t('terms.copyright.text') }}</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('terms.translation.title') }}</h2>
      <p>{{ $t('terms.translation.text') }}</p>
    </section>

    <section class="space-y-2">
      <h2 class="text-lg font-semibold">{{ $t('terms.limits.title') }}</h2>
      <p>{{ $t('terms.limits.text') }}</p>
    </section>
  </article>
</template>

<script setup lang="ts">
import { NAlert } from 'naive-ui'

const { t } = useI18n()
useHead({ title: () => t('terms.title') })
</script>
