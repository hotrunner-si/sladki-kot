<script setup>
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const router = useRouter()
const route = useRoute()
const checking = ref(false)
const error = ref('')
const showNewConfirm = ref(false)
const notice = computed(() => route.query.submitted
  ? `Popis je oddan v potrditev (${route.query.submitted} artiklov).`
  : route.query.discarded ? 'Popis je zavržen.' : '')

async function requestNewCount() {
  checking.value = true
  error.value = ''
  try {
    await supabase.rpc('expire_inventory_drafts')
    const cutoff = new Date(Date.now() - 36 * 60 * 60 * 1000).toISOString()
    const { data, error: queryError } = await supabase
      .from('inventory_counts')
      .select('id')
      .eq('status', 'incomplete')
      .gte('updated_at', cutoff)
      .limit(1)
    if (queryError) throw queryError
    if (data.length) showNewConfirm.value = true
    else await startNewCount()
  } catch {
    error.value = 'Preverjanje nezaključenih popisov ni uspelo.'
  } finally {
    checking.value = false
  }
}

async function startNewCount() {
  showNewConfirm.value = false
  await router.push({ path: '/count/new', query: { new: '1' } })
}

function openHistory() {
  showNewConfirm.value = false
  router.push('/history-counts')
}
</script>

<template>
  <section class="page">
    <header><p class="eyebrow">Sladki kot</p><h1>Popis</h1></header>
    <button class="start-card" :disabled="checking" @click="requestNewCount">
      <strong>Nov popis</strong><small>Začnite s praznim popisom zaloge</small><ArrowIcon direction="right" />
    </button>
    <RouterLink class="start-card" to="/history-counts">
      <strong>Zgodovina popisov</strong><small>Oddani, nezaključeni in zaključeni popisi</small><ArrowIcon direction="right" />
    </RouterLink>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="notice" class="success">{{ notice }}</p>
    <div v-if="showNewConfirm" class="detail-overlay">
      <article class="detail-card confirm-card">
        <h2>Obstaja še vsaj en nezaključen popis.</h2>
        <p>Ali želiš vseeno začeti nov popis?</p>
        <div class="actions">
          <button class="secondary" @click="startNewCount">Nov popis</button>
          <button @click="openHistory">Ne, nadaljuj star popis</button>
        </div>
      </article>
    </div>
  </section>
</template>
