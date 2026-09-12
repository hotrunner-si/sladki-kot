<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import { supabase } from '../lib/supabase'
import { getProducts } from '../services/data'
import { useAuth } from '../composables/useAuth'

const products=ref([]),quantities=ref({}),modes=ref({}),draftId=ref(null),hasDraft=ref(false),loading=ref(true),saving=ref(false),error=ref(''),message=ref(''),started=ref(false),search=ref(''),closed=ref({}),showDiscardConfirm=ref(false),showIncompleteConfirm=ref(false)
const {state}=useAuth()
let saveTimer, expiryTimer
const filtered=computed(()=>products.value.filter(p=>p.name.toLocaleLowerCase().includes(search.value.toLocaleLowerCase())))
const groups=computed(()=>filtered.value.reduce((a,p)=>((a[p.category]??=[]).push(p),a),{}))
const blankCount=computed(()=>products.value.filter(p=>quantities.value[p.id]===undefined||quantities.value[p.id]==='').length)

function step(p){return Number(p.count_step||1)}
function displayUnit(p){return modes.value[p.id]||p.unit}
function enteredBase(p){const q=Number(quantities.value[p.id]);return displayUnit(p)===p.alternative_unit?q*Number(p.alternative_unit_size):q}
function change(p,direction){const now=Number(quantities.value[p.id]||0);quantities.value[p.id]=Math.max(0,Number((now+direction*step(p)).toFixed(3)))}
function changeMode(p,event){const base=enteredBase(p);const next=event.target.value;modes.value[p.id]=next;quantities.value[p.id]=Number((next===p.alternative_unit?base/Number(p.alternative_unit_size):base).toFixed(3))}

async function loadDraft() {
  await supabase.rpc('expire_inventory_drafts')
  const { data, error: draftError } = await supabase.from('inventory_counts').select('id').eq('created_by',state.user.id).eq('status','draft').order('updated_at',{ascending:false}).limit(1).maybeSingle()
  if (draftError) throw draftError
  if (!data) return
  draftId.value=data.id;hasDraft.value=true
  const {data:items,error:itemsError}=await supabase.from('inventory_count_items').select('product_id,quantity').eq('inventory_count_id',data.id)
  if(itemsError)throw itemsError
  quantities.value=Object.fromEntries(items.map(i=>[i.product_id,Number(i.quantity)]))
}

onMounted(async()=>{try{products.value=await getProducts(true,false);products.value.forEach(p=>modes.value[p.id]=p.unit);await loadDraft()}catch{error.value='Popisa ni bilo mogoče naložiti.'}finally{loading.value=false}})

async function startOrResume(){
  error.value='';message.value=''
  if(!draftId.value){const id=crypto.randomUUID();const {error:e}=await supabase.from('inventory_counts').insert({id,created_by:state.user.id,status:'draft'});if(e){error.value='Novega popisa ni bilo mogoče začeti.';return}draftId.value=id;hasDraft.value=true}
  started.value=true;resetExpiryTimer()
}

async function saveDraft(){
  if(!draftId.value||!hasDraft.value)return
  const rows=products.value.filter(p=>quantities.value[p.id]!==undefined&&quantities.value[p.id]!=='').map(p=>({inventory_count_id:draftId.value,product_id:p.id,quantity:enteredBase(p)}))
  if(rows.length){const {error:e}=await supabase.from('inventory_count_items').upsert(rows,{onConflict:'inventory_count_id,product_id'});if(e)throw e}
  const {error:e}=await supabase.from('inventory_counts').update({updated_at:new Date().toISOString()}).eq('id',draftId.value).eq('status','draft');if(e)throw e
}

function scheduleSave(){if(!started.value||!draftId.value)return;clearTimeout(saveTimer);saveTimer=setTimeout(()=>saveDraft().catch(()=>{error.value='Sprotno shranjevanje ni uspelo.'}),450);resetExpiryTimer()}
function resetExpiryTimer(){clearTimeout(expiryTimer);if(started.value&&draftId.value)expiryTimer=setTimeout(expireCurrentDraft,10*60*1000)}
async function expireCurrentDraft(){try{await saveDraft();await supabase.from('inventory_counts').update({status:'incomplete'}).eq('id',draftId.value).eq('status','draft');draftId.value=null;hasDraft.value=false;started.value=false;quantities.value={};message.value='Popis je bil po 10 minutah nedejavnosti prenesen med nezaključene popise.'}catch{error.value='Popisa ni bilo mogoče samodejno shraniti.'}}
watch(quantities,scheduleSave,{deep:true})

async function discard(){saving.value=true;error.value='';try{if(draftId.value){const {error:e}=await supabase.from('inventory_counts').delete().eq('id',draftId.value);if(e)throw e}clearTimeout(saveTimer);clearTimeout(expiryTimer);draftId.value=null;hasDraft.value=false;quantities.value={};started.value=false;showDiscardConfirm.value=false;message.value='Popis je zavržen.'}catch{error.value='Popisa ni bilo mogoče zavreči.'}finally{saving.value=false}}

async function submitCount(){
  saving.value=true;error.value=''
  try{clearTimeout(saveTimer);await saveDraft();const submittedAt=new Date().toISOString();const {error:e}=await supabase.from('inventory_counts').update({status:'submitted',submitted_at:submittedAt,submitted_by:state.user.id,updated_at:submittedAt}).eq('id',draftId.value).eq('status','draft');if(e)throw e;clearTimeout(expiryTimer);const entered=products.value.length-blankCount.value;draftId.value=null;hasDraft.value=false;quantities.value={};started.value=false;showIncompleteConfirm.value=false;message.value=`Popis je oddan v potrditev (${entered} artiklov).`}catch{error.value='Popisa ni bilo mogoče oddati.'}finally{saving.value=false}
}
function finish(){if(blankCount.value)showIncompleteConfirm.value=true;else submitCount()}

onBeforeRouteLeave(async()=>{clearTimeout(saveTimer);clearTimeout(expiryTimer);if(started.value&&draftId.value)try{await saveDraft()}catch{}})
onBeforeUnmount(()=>{clearTimeout(saveTimer);clearTimeout(expiryTimer)})
</script>

<template><section class="page"><header><p class="eyebrow">Sladki kot</p><h1>Popis</h1></header><div v-if="loading" class="center-state">Nalagam artikle …</div><template v-else-if="!started"><button class="start-card" @click="startOrResume"><strong>{{hasDraft?'Nadaljuj popis':'Nov popis'}}</strong><small>{{hasDraft?'Nadaljujte z zadnjimi vnesenimi podatki':'Preštejte trenutno zalogo'}}</small><ArrowIcon direction="right" /></button><RouterLink class="start-card" to="/counts"><strong>Zgodovina popisov</strong><small>Oddani, nezaključeni in zaključeni popisi</small><ArrowIcon direction="right" /></RouterLink><p v-if="error" class="error">{{error}}</p><p v-if="message" class="success">{{message}}</p></template><template v-else><div class="count-toolbar"><input v-model="search" type="search" placeholder="Poišči izdelek …" aria-label="Poišči izdelek" /></div><section v-for="(items,category) in groups" :key="category" class="count-group"><button class="category-toggle" @click="closed[category]=!closed[category]"><strong>{{category}}</strong><ArrowIcon :direction="closed[category]?'down':'up'" /></button><div v-if="!closed[category]"><article v-for="p in items" :key="p.id" class="counter-item"><strong>{{p.name}}</strong><div class="counter-controls"><select v-if="p.alternative_unit" :value="modes[p.id]" @change="changeMode(p,$event)"><option :value="p.unit">{{p.unit}}</option><option :value="p.alternative_unit">{{p.alternative_unit}} ({{p.alternative_unit_size}} {{p.unit}})</option></select><small v-else>{{p.unit}}</small><button class="minus" @click="change(p,-1)">−</button><input v-model="quantities[p.id]" type="number" min="0" :step="step(p)" inputmode="decimal" :aria-label="p.name" /><button @click="change(p,1)">+</button></div></article></div></section><p v-if="error" class="error">{{error}}</p><div class="actions count-actions"><button class="secondary discard-count" :disabled="saving" @click="showDiscardConfirm=true">Zavrzi popis</button><button :disabled="saving" @click="finish">Zaključi popis</button></div><div v-if="showDiscardConfirm" class="detail-overlay"><article class="detail-card confirm-card"><h2>Ali želiš zavreči popis?</h2><p>Vsi vneseni podatki tega popisa bodo izbrisani.</p><div class="actions"><button class="secondary" @click="discard">Da</button><button @click="showDiscardConfirm=false">Nadaljuj popis</button></div></article></div><div v-if="showIncompleteConfirm" class="detail-overlay"><article class="detail-card confirm-card"><h2>Še {{blankCount}} polj je praznih.</h2><p>Želite oddati samo vnesene izdelke?</p><div class="actions"><button class="secondary" @click="submitCount">Oddaj nepopolno</button><button @click="showIncompleteConfirm=false">Nadaljuj popis</button></div></article></div></template></section></template>
