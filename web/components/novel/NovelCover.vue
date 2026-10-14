<template>
  <img
    :src="current"
    :alt="alt"
    :width="width"
    :height="height"
    loading="lazy"
    class="object-cover rounded flex-shrink-0 bg-gray-100"
    :style="{ width: `${width}px`, height: `${height}px` }"
    @error="failed = true"
  >
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  src?: string | null
  alt?: string
  width?: number
  height?: number
}>(), { src: null, alt: '', width: 80, height: 110 })

const PLACEHOLDER = '/placeholder-cover.svg'
const failed = ref(false)
watch(() => props.src, () => { failed.value = false })
const current = computed(() => (!props.src || failed.value) ? PLACEHOLDER : props.src)
</script>
