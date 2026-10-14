<template>
  <!-- <link rel="manifest"> for the PWA (rendered on the server as well). -->
  <NuxtPwaManifest />
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>

<script setup lang="ts">
const { t, locale } = useI18n()

// Pages set a short title; the site name is appended here. The template reads
// the current locale whenever the head is resolved (the description below
// changes with the locale, which re-resolves it).
function titleTemplate(title?: string) {
  return title ? `${title} — ${t('meta.siteName')}` : `${t('meta.siteName')} — ${t('meta.tagline')}`
}

useHead({
  htmlAttrs: { lang: locale },
  titleTemplate,
  meta: [{ name: 'description', content: computed(() => t('meta.description')) }],
})
</script>
