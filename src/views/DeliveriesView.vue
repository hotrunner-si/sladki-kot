<script setup>
import { computed, onMounted, ref } from 'vue'
import { supabase } from '../lib/supabase'
import { getProducts } from '../services/data'

const tab = ref('ordered'), products = ref([]), deliveries = ref([]), receivedItems = ref([])
const orderProductId = ref(''), expectedDate = ref(new Date().toISOString().slice(0, 10)), orderQuantity = ref(''), receivedQuantities = ref({})
const manualProductId = ref(''), manualQuantity = ref(''), showOrderForm = ref(false), showManualForm = ref(false)
const pendingDeleteItem = ref(null)
const loading = ref(true), saving = ref(false), error = ref(''), message = ref('')
const today = () => new Date().toLocaleDateString('en-CA')
const formatDate = value => value ? new Date(value).toLocaleDateString('sl-SI') : '—'
const orderProduct = computed(() => products.value.find(p => p.id === orderProductId.value))
const orderItems = computed(() => deliveries.value.flatMap(delivery => (delivery.delivery_items || []).map(item => ({ ...item, delivery }))))
const ordered = computed(() => orderItems.value.filter(item => !item.received_at && item.delivery.delivery_date > today()))
const awaitingReceipt = computed(() => orderItems.value.filter(item => !item.received_at && item.delivery.delivery_date <= today()))

async function load() {
  loading.value = true; error.value = ''
  try {
    const [productList, deliveriesResult, receivedResult] = await Promise.all([
      getProducts(),
      supabase.from('deliveries').select('id, delivery_date, suppliers(name), delivery_items(id, quantity, received_at, products(id,name,unit))').order('delivery_date'),
      supabase.from('delivery_items').select('id, quantity, received_at, products(id,name,unit)').not('received_at', 'is', null).order('received_at', { ascending: false }).limit(20),
    ])
    if (deliveriesResult.error || receivedResult.error) throw deliveriesResult.error || receivedResult.error
    products.value = productList; deliveries.value = deliveriesResult.data; receivedItems.value = receivedResult.data
    awaitingReceipt.value.forEach(item => { if (receivedQuantities.value[item.id] == null) receivedQuantities.value[item.id] = item.quantity })
  } catch { error.value = 'Podatkov o naročilih in zalogi ni bilo mogoče naložiti.' }
  finally { loading.value = false }
}

async function saveOrder() {
  error.value = ''; message.value = ''
  const product = orderProduct.value, quantity = Number(orderQuantity.value)
  if (!product || !expectedDate.value || !(quantity > 0)) { error.value = 'Izberite izdelek, datum in vnesite naročeno količino.'; return }
  if (!product.supplier_id) { error.value = 'Izbrani izdelek nima določenega dobavitelja. Najprej ga nastavite pri izdelku.'; return }
  saving.value = true
  try {
    const { data, error: deliveryError } = await supabase.from('deliveries').insert({ supplier_id: product.supplier_id, delivery_date: expectedDate.value }).select().single()
    if (deliveryError) throw deliveryError
    const { error: itemsError } = await supabase.from('delivery_items').insert({ delivery_id: data.id, product_id: product.id, quantity })
    if (itemsError) throw itemsError
    orderProductId.value = ''; orderQuantity.value = ''; showOrderForm.value = false; message.value = 'Naročilo je shranjeno.'; await load()
  } catch { error.value = 'Naročila ni bilo mogoče shraniti.' }
  finally { saving.value = false }
}

async function confirmReceipt(item) {
  error.value = ''; message.value = ''
  const quantity = Number(receivedQuantities.value[item.id])
  if (!(quantity > 0)) { error.value = 'Vnesite prejeto količino.'; return }
  saving.value = true
  try {
    const { error: updateError } = await supabase.from('delivery_items').update({ quantity, received_at: new Date().toISOString() }).eq('id', item.id)
    if (updateError) throw updateError
    message.value = `${item.products.name}: nova zaloga je potrjena.`; await load()
  } catch { error.value = 'Nove zaloge ni bilo mogoče potrditi.' }
  finally { saving.value = false }
}

async function discardReceipt(item) {
  saving.value = true; error.value = ''; message.value = ''
  try {
    const { error: deleteError } = await supabase.from('delivery_items').delete().eq('id', item.id).is('received_at', null)
    if (deleteError) throw deleteError
    message.value = `${item.products.name} je odstranjen iz dobav.`; pendingDeleteItem.value = null; await load()
  } catch { error.value = 'Izdelka ni bilo mogoče odstraniti.' }
  finally { saving.value = false }
}

async function addManualStock() {
  error.value = ''; message.value = ''
  const quantity = Number(manualQuantity.value)
  if (!manualProductId.value || !(quantity > 0)) { error.value = 'Izberite izdelek in vnesite količino.'; return }
  saving.value = true
  try {
    const { error: insertError } = await supabase.from('delivery_items').insert({ delivery_id: null, product_id: manualProductId.value, quantity, received_at: new Date().toISOString() })
    if (insertError) throw insertError
    manualProductId.value = ''; manualQuantity.value = ''; showManualForm.value = false; message.value = 'Nova zaloga je dodana.'; await load()
  } catch { error.value = 'Nove zaloge ni bilo mogoče dodati.' }
  finally { saving.value = false }
}
onMounted(load)
</script>

<template>
  <section class="page deliveries-page">
    <header><p class="eyebrow">Sladki kot</p><h1>Dobave</h1><p class="muted">Naročila in prejeta zaloga</p></header>
    <nav class="delivery-tabs" aria-label="Vrsta dobave"><button :class="{ active: tab === 'ordered' }" @click="tab='ordered'">Naročeno <span>{{ordered.length}}</span></button><button :class="{ active: tab === 'stock' }" @click="tab='stock'">Nova zaloga <span>{{awaitingReceipt.length}}</span></button></nav>
    <p v-if="error" class="error">{{error}}</p><p v-if="message" class="success">{{message}}</p>
    <div v-if="loading" class="center-state">Nalagam dobave …</div>
    <template v-else-if="tab === 'ordered'">
      <div class="section-heading"><div><h2>Naročeni izdelki</h2><p class="muted">Izdelki na poti in predvideni datumi dostave</p></div><button @click="showOrderForm=!showOrderForm">Dodaj naročilo</button></div>
      <form v-if="showOrderForm" class="card stack delivery-form" @submit.prevent="saveOrder"><label>Izdelek<select v-model="orderProductId"><option value="">Izberite izdelek</option><option v-for="p in products.filter(item => item.active)" :key="p.id" :value="p.id">{{p.name}} ({{p.unit}})</option></select></label><label>Predvideni datum dostave<input v-model="expectedDate" type="date" required /></label><label>Naročena količina<input v-model="orderQuantity" type="number" min="0.001" step="0.001" inputmode="decimal" required /></label><div class="form-actions"><button type="button" class="secondary" @click="showOrderForm=false">Prekliči</button><button :disabled="saving">Shrani naročilo</button></div></form>
      <div v-if="!ordered.length" class="delivery-empty">Trenutno ni izdelkov na poti.</div><div v-else class="delivery-list"><article v-for="item in ordered" :key="item.id" class="delivery-item"><div><strong>{{item.products.name}}</strong><small>{{item.delivery.suppliers?.name}} · {{item.quantity}} {{item.products.unit}}</small></div><div class="delivery-order-side"><time><small>Predvidena dostava</small>{{formatDate(item.delivery.delivery_date)}}</time><TrashButton :disabled="saving" :label="`Odstrani naročilo za ${item.products.name}`" @click="pendingDeleteItem=item" /></div></article></div>
    </template>
    <template v-else>
      <div class="section-heading"><div><h2>Nova zaloga</h2><p class="muted">Potrdite prejete količine ali jih dodajte ročno</p></div><button @click="showManualForm=!showManualForm">Dodaj izdelek</button></div>
      <form v-if="showManualForm" class="card stack delivery-form" @submit.prevent="addManualStock"><label>Izdelek<select v-model="manualProductId"><option value="">Izberite izdelek</option><option v-for="p in products" :key="p.id" :value="p.id">{{p.name}} ({{p.unit}})</option></select></label><label>Nova količina<input v-model="manualQuantity" type="number" min="0.001" step="0.001" inputmode="decimal" required /></label><div class="form-actions"><button type="button" class="secondary" @click="showManualForm=false">Prekliči</button><button :disabled="saving">Dodaj zalogo</button></div></form>
      <div v-if="!awaitingReceipt.length" class="delivery-empty">Ni novih dobav, ki čakajo na potrditev.</div><div v-else class="delivery-list"><article v-for="item in awaitingReceipt" :key="item.id" class="delivery-item receipt-item"><div class="receipt-heading"><span><strong>{{item.products.name}}</strong><small>Naročeno: {{item.quantity}} {{item.products.unit}} · {{formatDate(item.delivery.delivery_date)}}</small></span><TrashButton :disabled="saving" :label="`Odstrani ${item.products.name} iz nove zaloge`" @click="pendingDeleteItem=item" /></div><div class="receipt-actions"><input v-model="receivedQuantities[item.id]" type="number" min="0.001" step="0.001" :aria-label="`Prejeta količina za ${item.products.name}`"/><span>{{item.products.unit}}</span><button :disabled="saving" @click="confirmReceipt(item)">Potrdi novo zalogo</button></div></article></div>
      <section v-if="receivedItems.length" class="received-history"><h2>Nazadnje potrjeno</h2><div class="delivery-list"><article v-for="item in receivedItems" :key="item.id" class="delivery-item"><div><strong>{{item.products.name}}</strong><small>+ {{item.quantity}} {{item.products.unit}}</small></div><time>{{formatDate(item.received_at)}}</time></article></div></section>
    </template>
    <div v-if="pendingDeleteItem" class="detail-overlay"><article class="detail-card confirm-card"><h2>Odstranim {{pendingDeleteItem.products.name}}?</h2><p>Izdelek bo odstranjen iz naročenih oziroma čakajočih dobav. Tega dejanja ni mogoče razveljaviti.</p><div class="actions"><button class="secondary" :disabled="saving" @click="discardReceipt(pendingDeleteItem)">Da, izbriši</button><button @click="pendingDeleteItem=null">Prekliči</button></div></article></div>
  </section>
</template>
