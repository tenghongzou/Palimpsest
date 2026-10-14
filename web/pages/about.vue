<template>
  <article class="max-w-3xl mx-auto space-y-6 leading-relaxed">
    <h1 class="text-2xl font-bold">{{ $t('about.heading') }}</h1>
    <p>{{ $t('about.intro') }}</p>
    <h2 class="text-lg font-semibold">{{ $t('about.featuresTitle') }}</h2>
    <ul class="list-disc pl-6 space-y-1">
      <li>{{ $t('about.features.conversion') }}</li>
      <li>{{ $t('about.features.offline') }}</li>
      <li>{{ $t('about.features.community') }}</li>
    </ul>
    <p class="text-sm text-gray-500">
      <i18n-t keypath="about.seeLegal" scope="global">
        <template #terms>
          <NuxtLink to="/terms" class="text-primary">{{ $t('footer.terms') }}</NuxtLink>
        </template>
        <template #privacy>
          <NuxtLink to="/privacy" class="text-primary">{{ $t('footer.privacy') }}</NuxtLink>
        </template>
      </i18n-t>
    </p>
  </article>
</template>

<script setup lang="ts">
const { t } = useI18n()
useHead({ title: () => t('about.title') })
</script>
