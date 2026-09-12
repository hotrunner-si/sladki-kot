<script setup>
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import ThemeToggle from './ThemeToggle.vue'
import HelpButton from './HelpButton.vue'
const router = useRouter(); const { state, signOut } = useAuth()
async function out() { await signOut(); router.replace('/login') }
</script>
<template>
    <aside class="user-bar">
        <div><strong>{{ state.profile?.full_name || state.user?.email }}</strong><small>{{ state.profile?.role ===
            'admin' ? 'Administrator' : 'Popis zaloge' }}</small></div><div class="user-bar-actions"><HelpButton /><ThemeToggle /><button class="logout"
            @click="out">Odjava</button></div>
    </aside>
</template>
