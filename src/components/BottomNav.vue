<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuth } from '../composables/useAuth'
const { state } = useAuth()
const route = useRoute()
const activeSection = computed(() => {
  if (['/count', '/count/new', '/history-counts', '/counts'].includes(route.path)) return 'count'
  if (['/more', '/schedule', '/suppliers', '/users'].includes(route.path)) return 'more'
  return route.path.slice(1)
})
</script>
<template><nav class="bottom-nav"><template v-if="state.profile?.role === 'admin'"><RouterLink to="/dashboard" :class="{'bottom-nav__active':activeSection==='dashboard'}">Pregled</RouterLink><RouterLink to="/count" :class="{'bottom-nav__active':activeSection==='count'}">Popis</RouterLink><RouterLink to="/deliveries" :class="{'bottom-nav__active':activeSection==='deliveries'}">Dobave</RouterLink><RouterLink to="/products" :class="{'bottom-nav__active':activeSection==='products'}">Izdelki</RouterLink><RouterLink to="/more" :class="{'bottom-nav__active':activeSection==='more'}">Več</RouterLink></template><template v-else><RouterLink to="/dashboard" :class="{'bottom-nav__active':activeSection==='dashboard'}">Pregled</RouterLink><RouterLink to="/count" :class="{'bottom-nav__active':activeSection==='count'}">Popis</RouterLink><RouterLink to="/products" :class="{'bottom-nav__active':activeSection==='products'}">Izdelki</RouterLink></template></nav></template>
