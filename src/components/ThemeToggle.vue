<script setup>
import { computed, onMounted, ref } from 'vue'

const STORAGE_KEY = 'sladki-kot-theme'
const theme = ref('light')
const isDark = computed(() => theme.value === 'dark')

function applyTheme(nextTheme) {
  theme.value = nextTheme
  document.documentElement.dataset.theme = nextTheme
  document.querySelector('meta[name="theme-color"]')?.setAttribute(
    'content',
    nextTheme === 'dark' ? '#17231e' : '#fffaf0',
  )
  localStorage.setItem(STORAGE_KEY, nextTheme)
}

function toggleTheme() {
  applyTheme(isDark.value ? 'light' : 'dark')
}

onMounted(() => {
  const savedTheme = localStorage.getItem(STORAGE_KEY)
  applyTheme(savedTheme === 'dark' ? 'dark' : 'light')
})
</script>

<template>
  <button
    class="theme-toggle"
    type="button"
    :aria-label="isDark ? 'Vklopi svetlo temo' : 'Vklopi temno temo'"
    :title="isDark ? 'Svetla tema' : 'Temna tema'"
    @click="toggleTheme"
  >
    <svg v-if="isDark" class="theme-toggle__icon" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 1v3M12 20v3M1 12h3M20 12h3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M17.7 6.3l2.1-2.1M4.2 19.8l2.1-2.1" />
    </svg>
    <svg v-else class="theme-toggle__icon" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79Z" />
    </svg>
  </button>
</template>
