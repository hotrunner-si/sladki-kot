<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuth } from '../composables/useAuth'

const counts=ref([]),selected=ref(null),items=ref([]),loading=ref(true),detailsLoading=ref(false),working=ref(false),error=ref('')
const router=useRouter(),{state,isAdmin}=useAuth(),canApprove=computed(()=>isAdmin())
const labels={incomplete:'Nezaključen',submitted:'Oddan',completed:'Zaključen'}
const eventDate=c=>c.submitted_at||c.completed_at||c.updated_at||c.started_at
const formatDateTime=value=>new Intl.DateTimeFormat('sl-SI',{timeZone:'Europe/Ljubljana',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'}).format(new Date(value))

async function load(){
  loading.value=true;error.value=''
  try{
    await supabase.rpc('expire_inventory_drafts')
    const [countsResult,profilesResult,itemsResult]=await Promise.all([
      supabase.from('inventory_counts').select('*').neq('status','draft').order('started_at',{ascending:false}),
      supabase.from('profiles').select('id,full_name'),
      supabase.from('inventory_count_items').select('inventory_count_id,product_id'),
    ])
    if(countsResult.error||profilesResult.error||itemsResult.error)throw countsResult.error||profilesResult.error||itemsResult.error
    const names=new Map(profilesResult.data.map(p=>[p.id,p.full_name]))
    const countById=new Map(countsResult.data.map(c=>[c.id,c]))
    const latestByProduct=new Map()
    for(const item of itemsResult.data){const count=countById.get(item.inventory_count_id);if(!count||count.status!=='completed')continue;const old=latestByProduct.get(item.product_id);if(!old||new Date(count.completed_at)>new Date(old.completed_at))latestByProduct.set(item.product_id,count)}
    const contribution=new Map()
    for(const count of latestByProduct.values())contribution.set(count.id,(contribution.get(count.id)||0)+1)
    const total=latestByProduct.size||1
    counts.value=countsResult.data.map(c=>({...c,creatorName:names.get(c.created_by)||'—',submitterName:names.get(c.submitted_by)||names.get(c.created_by)||'—',share:c.status==='completed'?(contribution.get(c.id)||0)/total*100:0}))
  }catch{error.value='Zgodovine ni bilo mogoče naložiti. Preverite pravice uporabnika in poskusite ponovno.'}
  finally{loading.value=false}
}

async function open(c){selected.value=c;items.value=[];detailsLoading.value=true;error.value='';try{const{data,error:e}=await supabase.from('inventory_count_items').select('quantity, products(name,unit)').eq('inventory_count_id',c.id);if(e)throw e;items.value=data.sort((a,b)=>(a.products?.name||'').localeCompare(b.products?.name||''))}catch{error.value='Podrobnosti popisa ni bilo mogoče naložiti.'}finally{detailsLoading.value=false}}
async function approve(c){working.value=true;error.value='';try{const{error:e}=await supabase.from('inventory_counts').update({status:'completed',completed_at:c.submitted_at||new Date().toISOString()}).eq('id',c.id).eq('status','submitted');if(e)throw e;selected.value=null;await load()}catch{error.value='Popisa ni bilo mogoče potrditi.'}finally{working.value=false}}
async function takeOver(c){working.value=true;error.value='';try{const{data:existing,error:checkError}=await supabase.from('inventory_counts').select('id').eq('created_by',state.user.id).eq('status','draft').limit(1);if(checkError)throw checkError;if(existing.length){error.value='Najprej zaključite ali zavrzite svoj trenutni popis.';return}const{error:e}=await supabase.from('inventory_counts').update({status:'draft',created_by:state.user.id,updated_at:new Date().toISOString()}).eq('id',c.id).eq('status','incomplete');if(e)throw e;router.push('/count')}catch{error.value='Nezaključenega popisa ni bilo mogoče prevzeti.'}finally{working.value=false}}
onMounted(load)
</script>

<template><section class="page history-page"><header><p class="eyebrow">Sladki kot</p><h1>Zgodovina popisov</h1><p class="muted">Nezaključeni, oddani in zaključeni popisi</p></header><p v-if="error" class="error">{{error}}</p><div v-if="loading" class="center-state">Nalagam zgodovino …</div><template v-else-if="selected"><button class="history-back" @click="selected=null"><ArrowIcon direction="left" /> Vsi popisi</button><section class="history-detail"><p class="eyebrow">{{labels[selected.status]}} POPIS</p><h2>{{formatDateTime(eventDate(selected))}}</h2><p class="muted">{{selected.status==='incomplete'?'Začel':'Oddal'}}: {{selected.status==='incomplete'?selected.creatorName:selected.submitterName}}</p><div class="history-detail-actions"><button v-if="selected.status==='incomplete'" :disabled="working" @click="takeOver(selected)">Prevzemi in nadaljuj</button><button v-if="selected.status==='submitted'&&canApprove" :disabled="working" @click="approve(selected)">Potrdi popis</button></div></section><div v-if="detailsLoading" class="center-state">Nalagam artikle …</div><div v-else class="history-items"><div v-for="i in items" :key="i.products?.name" class="history-item"><strong>{{i.products?.name}}</strong><span>{{i.quantity}} {{i.products?.unit}}</span></div></div></template><div v-else-if="!counts.length" class="history-empty">Popisov še ni.</div><div v-else class="history-list"><article v-for="c in counts" :key="c.id" class="history-row-wrap"><button class="history-row" @click="open(c)"><span class="history-date"><strong>{{formatDateTime(eventDate(c))}}</strong><small>{{c.status==='incomplete'?'Začel':'Oddal'}}: {{c.status==='incomplete'?c.creatorName:c.submitterName}}</small></span><span class="history-status" :class="`history-status--${c.status}`">{{labels[c.status]}}</span><span class="history-arrow"><ArrowIcon direction="right" /></span></button><div class="history-share" :title="`${c.share.toFixed(1)} % trenutnih popisanih vrednosti`"><span :style="{width:`${c.share}%`}"></span></div></article></div></section></template>
