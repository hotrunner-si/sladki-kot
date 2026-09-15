<script setup>
import { computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAuth } from './composables/useAuth'
import BottomNav from './components/BottomNav.vue'
import UserBar from './components/UserBar.vue'
const { initialize, state } = useAuth(); const route = useRoute(); const isStandalone = computed(() => route.meta.standalone); onMounted(initialize)
</script>
<template><main class="app-shell" :class="{'app-shell--standalone': isStandalone}"><div v-if="!state.ready" class="center-state">Nalagam aplikacijo …</div><template v-else><UserBar v-if="state.user&&!isStandalone" /><RouterView /><BottomNav v-if="state.user&&!isStandalone" /></template></main></template>
