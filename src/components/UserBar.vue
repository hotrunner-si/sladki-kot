<script setup>
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
const router = useRouter(); const { state, signOut } = useAuth()
async function out() { await signOut(); router.replace('/login') }
</script>
<template>
    <aside class="user-bar">
        <div><strong>{{ state.profile?.full_name || state.user?.email }}</strong><small>{{ state.profile?.role ===
            'admin' ? 'Administrator' : 'Popis zaloge' }}</small></div><button class="logout"
            @click="out">Odjava</button>
    </aside>
</template>
