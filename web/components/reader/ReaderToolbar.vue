<template>
  <div class="reader-toolbar">
    <!-- TODO: chapter nav, settings toggle, bookmark, translate button -->
  </div>
</template>

<script setup lang="ts">
defineEmits<{
  openSettings: []
  openChapterList: []
  toggleBookmark: []
  translate: []
}>()
</script>
