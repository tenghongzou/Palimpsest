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

// Default share card (public/og-image.png, the stacked logo). Crawlers need an
// absolute URL. Pages that call useSeoMeta({ ogImage }) replace it, since
// entries added later win for the same property.
const ogImage = `${useRequestURL().origin}/og-image.png`
useSeoMeta({
  ogSiteName: 'Palimpsest',
  ogImage,
  ogImageWidth: 1200,
  ogImageHeight: 630,
  ogImageAlt: 'Palimpsest',
  twitterCard: 'summary_large_image',
  twitterImage: ogImage,
})
</script>
