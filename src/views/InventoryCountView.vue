<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { getProducts } from '../services/data'
import { useAuth } from '../composables/useAuth'

const products=ref([]),quantities=ref({}),modes=ref({}),draftId=ref(null),loading=ref(true),saving=ref(false),error=ref(''),search=ref(''),closed=ref({}),showDiscardConfirm=ref(false),showIncompleteConfirm=ref(false)
const {state}=useAuth(),router=useRouter(),route=useRoute()
let saveTimer,presenceTimer,isLeaving=false
const filtered=computed(()=>products.value.filter(p=>p.name.toLocaleLowerCase().includes(search.value.toLocaleLowerCase())))
const groups=computed(()=>filtered.value.reduce((a,p)=>((a[p.category]??=[]).push(p),a),{}))
const blankCount=computed(()=>products.value.filter(p=>quantities.value[p.id]===undefined||quantities.value[p.id]==='').length)
const hasEntries=computed(()=>blankCount.value<products.value.length)

function step(p){return Number(p.count_step||1)}
function displayUnit(p){return modes.value[p.id]||p.unit}
function enteredBase(p){const q=Number(quantities.value[p.id]);return displayUnit(p)===p.alternative_unit?q*Number(p.alternative_unit_size):q}
function change(p,direction){const now=Number(quantities.value[p.id]||0);quantities.value[p.id]=Math.max(0,Number((now+direction*step(p)).toFixed(3)))}
function changeMode(p,event){const base=enteredBase(p),next=event.target.value;modes.value[p.id]=next;quantities.value[p.id]=Number((next===p.alternative_unit?base/Number(p.alternative_unit_size):base).toFixed(3))}

async function loadResumedCount(id){
  const{data,error:draftError}=await supabase.from('inventory_counts').select('id').eq('id',id).eq('status','draft').eq('last_edited_by',state.user.id).maybeSingle()
  if(draftError)throw draftError
  if(!data)throw new Error('missing count')
  const{data:items,error:itemsError}=await supabase.from('inventory_count_items').select('product_id,quantity').eq('inventory_count_id',data.id)
  if(itemsError)throw itemsError
  draftId.value=data.id
  quantities.value=Object.fromEntries(items.map(i=>[i.product_id,Number(i.quantity)]))
  await setPresent()
}

onMounted(async()=>{
  try{
    products.value=await getProducts(true,false)
    products.value.forEach(p=>modes.value[p.id]=p.unit)
    if(route.query.resume)await loadResumedCount(route.query.resume)
    else if(!route.query.new)await router.replace('/count')
  }catch{error.value='Popisa ni bilo mogoče naložiti.'}
  finally{loading.value=false}
})

async function ensureDraft(){if(draftId.value||!hasEntries.value)return;const id=crypto.randomUUID(),now=new Date(),activeUntil=new Date(now.getTime()+60000).toISOString();const{error:e}=await supabase.from('inventory_counts').insert({id,created_by:state.user.id,last_edited_by:state.user.id,status:'draft',active_until:activeUntil});if(e)throw e;draftId.value=id;startPresence()}
async function setPresent(){if(!draftId.value)return;const now=new Date(),activeUntil=new Date(now.getTime()+60000).toISOString();const{error:e}=await supabase.from('inventory_counts').update({status:'draft',active_until:activeUntil,updated_at:now.toISOString()}).eq('id',draftId.value);if(e)throw e;startPresence()}
function startPresence(){clearInterval(presenceTimer);presenceTimer=setInterval(()=>{if(draftId.value)supabase.from('inventory_counts').update({active_until:new Date(Date.now()+60000).toISOString()}).eq('id',draftId.value).eq('status','draft')},25000)}

async function saveDraft(){
  await ensureDraft();if(!draftId.value)return
  const rows=products.value.filter(p=>quantities.value[p.id]!==undefined&&quantities.value[p.id]!=='').map(p=>({inventory_count_id:draftId.value,product_id:p.id,quantity:enteredBase(p)}))
  if(rows.length){const{error:e}=await supabase.from('inventory_count_items').upsert(rows,{onConflict:'inventory_count_id,product_id'});if(e)throw e}
  const{error:e}=await supabase.from('inventory_counts').update({updated_at:new Date().toISOString(),last_edited_by:state.user.id}).eq('id',draftId.value).eq('status','draft');if(e)throw e
}

function scheduleSave(){if(!hasEntries.value)return;clearTimeout(saveTimer);saveTimer=setTimeout(()=>saveDraft().catch(()=>{error.value='Sprotno shranjevanje ni uspelo.'}),450)}
watch(quantities,scheduleSave,{deep:true})

async function discard(){saving.value=true;error.value='';try{if(draftId.value){const{error:e}=await supabase.from('inventory_counts').delete().eq('id',draftId.value);if(e)throw e}clearTimeout(saveTimer);clearInterval(presenceTimer);draftId.value=null;quantities.value={};showDiscardConfirm.value=false;isLeaving=true;await router.push({path:'/count',query:{discarded:'1'}})}catch{error.value='Popisa ni bilo mogoče zavreči.'}finally{saving.value=false}}

async function submitCount(){
  saving.value=true;error.value=''
  try{clearTimeout(saveTimer);await saveDraft();const submittedAt=new Date().toISOString();const{error:e}=await supabase.from('inventory_counts').update({status:'submitted',submitted_at:submittedAt,submitted_by:state.user.id,updated_at:submittedAt,active_until:null}).eq('id',draftId.value).eq('status','draft');if(e)throw e;clearInterval(presenceTimer);const entered=products.value.length-blankCount.value;draftId.value=null;quantities.value={};showIncompleteConfirm.value=false;isLeaving=true;await router.push({path:'/count',query:{submitted:String(entered)}})}catch{error.value='Popisa ni bilo mogoče oddati.'}finally{saving.value=false}
}
function finish(){if(!hasEntries.value){error.value='Vnesite vsaj eno količino.';return}if(blankCount.value)showIncompleteConfirm.value=true;else submitCount()}
async function markAway(){clearTimeout(saveTimer);clearInterval(presenceTimer);if(draftId.value&&hasEntries.value){await saveDraft();await supabase.from('inventory_counts').update({status:'incomplete',active_until:null}).eq('id',draftId.value).eq('status','draft')}}
onBeforeRouteLeave(async()=>{if(!isLeaving){try{await markAway()}catch{}}})
onBeforeUnmount(()=>{clearTimeout(saveTimer);clearInterval(presenceTimer)})
</script>

<template><section class="page"><header><p class="eyebrow">Sladki kot</p><h1>Nov popis</h1></header><div v-if="loading" class="center-state">Nalagam artikle …</div><template v-else><div class="count-toolbar"><input v-model="search" type="search" placeholder="Poišči izdelek …" aria-label="Poišči izdelek" /></div><section v-for="(items,category) in groups" :key="category" class="count-group"><button class="category-toggle" @click="closed[category]=!closed[category]"><strong>{{category}}</strong><ArrowIcon :direction="closed[category]?'down':'up'" /></button><div v-if="!closed[category]"><article v-for="p in items" :key="p.id" class="counter-item"><strong>{{p.name}}</strong><div class="counter-controls"><select v-if="p.alternative_unit" :value="modes[p.id]" @change="changeMode(p,$event)"><option :value="p.unit">{{p.unit}}</option><option :value="p.alternative_unit">{{p.alternative_unit}} ({{p.alternative_unit_size}} {{p.unit}})</option></select><small v-else>{{p.unit}}</small><button class="minus" @click="change(p,-1)">−</button><input v-model="quantities[p.id]" type="number" min="0" :step="step(p)" inputmode="decimal" :aria-label="p.name" /><button @click="change(p,1)">+</button></div></article></div></section><p v-if="error" class="error">{{error}}</p><div class="actions count-actions"><button class="secondary discard-count" :disabled="saving" @click="showDiscardConfirm=true">Zavrzi popis</button><button :disabled="saving" @click="finish">Zaključi popis</button></div><div v-if="showDiscardConfirm" class="detail-overlay"><article class="detail-card confirm-card"><h2>Ali želiš zavreči popis?</h2><p>Vsi vneseni podatki tega popisa bodo izbrisani.</p><div class="actions"><button class="secondary" @click="discard">Da</button><button @click="showDiscardConfirm=false">Nadaljuj popis</button></div></article></div><div v-if="showIncompleteConfirm" class="detail-overlay"><article class="detail-card confirm-card"><h2>Še {{blankCount}} polj je praznih.</h2><p>Želite oddati samo vnesene izdelke?</p><div class="actions"><button class="secondary" @click="submitCount">Oddaj nepopolno</button><button @click="showIncompleteConfirm=false">Nadaljuj popis</button></div></article></div></template></section></template>
