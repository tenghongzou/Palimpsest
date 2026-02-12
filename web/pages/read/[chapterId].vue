<template>
  <div class="reader-page">
    <!-- TODO: reader content, toolbar, settings panel, chapter navigation -->
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'reader' })
const route = useRoute()
const chapterId = route.params.chapterId as string
</script>
