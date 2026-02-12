<template>
  <div class="novel-card">
    <!-- TODO: cover image, title, author, rating, status -->
  </div>
</template>

<script setup lang="ts">
import type { Novel } from '~/types/novel'

defineProps<{
  novel: Novel
}>()
</script>
