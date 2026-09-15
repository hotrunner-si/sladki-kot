<script setup>
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import LogoutIcon from '../components/LogoutIcon.vue'
const router = useRouter(); const { signOut, state } = useAuth(); async function out() { await signOut(); router.replace('/login') }
</script>
<template>
    <section class="page more-page">
        <header class="more-header">
            <p class="eyebrow">Sladki kot</p>
            <h1>Več</h1>
            <p class="muted">Nastavitve in zgodovina zaloge</p>
        </header>
        <section class="account-panel"><span
                class="account-avatar">{{ (state.profile?.full_name || state.user?.email || '?').slice(0, 1).toUpperCase() }}</span>
            <div><strong>{{ state.profile?.full_name || state.user?.email }}</strong><small>Administrator</small></div>
        </section>
        <p class="more-label">UPRAVLJANJE</p>
        <nav class="more-menu">
            <RouterLink class="more-item" to="/history-counts"><span class="more-icon">◷</span><span><strong>Zgodovina
                        popisov</strong><small>Zaključeni in shranjeni popisi</small></span>
                <ArrowIcon direction="right" />
            </RouterLink>
            <RouterLink class="more-item" to="/schedule"><span class="more-icon">▣</span><span><strong>Urnik
                        dela</strong><small>Prodajne ure in razpored zaposlenih</small></span>
                <ArrowIcon direction="right" />
            </RouterLink>
            <RouterLink class="more-item" to="/suppliers"><span
                    class="more-icon">▦</span><span><strong>Dobavitelji</strong><small>Kontakti in dobavni
                        roki</small></span>
                <ArrowIcon direction="right" />
            </RouterLink>
            <RouterLink class="more-item" to="/users"><span
                    class="more-icon">◉</span><span><strong>Uporabniki</strong><small>Vloge v aplikaciji</small></span>
                <ArrowIcon direction="right" />
            </RouterLink>
        </nav><button class="signout-button" @click="out">
            <LogoutIcon /> Odjava
        </button>
    </section>
</template>
