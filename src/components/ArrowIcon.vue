<script setup>
defineProps({
  direction: {
    type: String,
    default: 'right',
    validator: (value) => ['up', 'down', 'left', 'right'].includes(value),
  },
})
</script>

<template>
  <svg class="direction-icon" :class="`direction-icon--${direction}`" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <path d="m9 18 6-6-6-6" />
  </svg>
</template>
