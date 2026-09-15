<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { helpContent, helpKeyByPath } from '../content/helpContent'
import { useAuth } from '../composables/useAuth'
const props=defineProps({helpKey:{type:String,default:''}}),route=useRoute(),open=ref(false)
const key=computed(()=>props.helpKey||helpKeyByPath[route.path]||'default'),content=computed(()=>helpContent[key.value]||helpContent.default)
const {isAdmin}=useAuth(),tips=computed(()=>[...content.value.tips,...(isAdmin()?content.value.adminTips||[]:[])])
function close(){open.value=false}function onKeydown(event){if(event.key==='Escape')close()}
watch(()=>route.fullPath,close);onMounted(()=>window.addEventListener('keydown',onKeydown));onBeforeUnmount(()=>window.removeEventListener('keydown',onKeydown))
</script>
<template><button class="help-button" type="button" aria-label="Odpri pomoč za to stran" title="Pomoč" @click="open=true">?</button><Teleport to="body"><div v-if="open" class="help-overlay" @click.self="close"><article class="help-dialog" role="dialog" aria-modal="true" :aria-labelledby="`help-title-${key}`"><button class="help-close" type="button" aria-label="Zapri pomoč" @click="close">×</button><p class="eyebrow">POMOČ</p><h2 :id="`help-title-${key}`">{{content.title}}</h2><p>{{content.intro}}</p><ul><li v-for="tip in tips" :key="tip">{{tip}}</li></ul><button class="help-done" type="button" @click="close">Razumem</button></article></div></Teleport></template>
