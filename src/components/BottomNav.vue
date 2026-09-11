<script setup>
import { useAuth } from '../composables/useAuth'
const { state } = useAuth()
</script>
<template><nav class="bottom-nav"><template v-if="state.profile?.role === 'admin'"><RouterLink to="/dashboard">Pregled</RouterLink><RouterLink to="/count">Popis</RouterLink><RouterLink to="/deliveries">Dobave</RouterLink><RouterLink to="/products">Izdelki</RouterLink><RouterLink to="/more">Več</RouterLink></template><template v-else><RouterLink to="/count">Nov popis</RouterLink></template></nav></template>
