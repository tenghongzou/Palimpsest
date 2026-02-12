<template>
  <div class="novel-detail-page">
    <!-- TODO: novel info, rating, chapters, add-to-bookshelf -->
  </div>
</template>

<script setup lang="ts">
const route = useRoute()
const novelId = route.params.id as string
useHead({ title: 'Palimpsest' }) // TODO: dynamic title from novel data
</script>
