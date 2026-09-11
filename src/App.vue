<script setup>
import { onMounted } from 'vue'
import { useAuth } from './composables/useAuth'
import BottomNav from './components/BottomNav.vue'
import UserBar from './components/UserBar.vue'
const { initialize, state } = useAuth(); onMounted(initialize)
</script>
<template><main class="app-shell"><div v-if="!state.ready" class="center-state">Nalagam aplikacijo …</div><template v-else><UserBar v-if="state.user" /><RouterView /><BottomNav v-if="state.user" /></template></main></template>
