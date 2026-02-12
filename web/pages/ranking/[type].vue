<template>
  <div class="ranking-page">
    <!-- TODO: ranking list with period tabs (daily/weekly/monthly/all) -->
  </div>
</template>

<script setup lang="ts">
const route = useRoute()
const rankingType = route.params.type as string
</script>
