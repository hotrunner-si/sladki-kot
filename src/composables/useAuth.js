import { reactive, readonly } from 'vue'
import { supabase, supabaseConfigured } from '../lib/supabase'
const state = reactive({ ready: false, user: null, profile: null, configurationError: false })
async function loadProfile() { if (!state.user) { state.profile = null; return }; const { data } = await supabase.from('profiles').select('*').eq('id', state.user.id).single(); state.profile = data }
async function initialize() { try { if (!supabaseConfigured) throw new Error('missing configuration'); const { data, error } = await supabase.auth.getSession(); if (error) throw error; state.user = data.session?.user || null; await loadProfile(); supabase.auth.onAuthStateChange(async (_e, session) => { state.user = session?.user || null; await loadProfile() }) } catch { state.configurationError = true; state.user = null; state.profile = null } finally { state.ready = true } }
async function signIn(email, password) { const { error } = await supabase.auth.signInWithPassword({ email, password }); if (error) throw error; await loadProfile() }
async function signOut() { await supabase.auth.signOut(); state.user = null; state.profile = null }
export function useAuth() { return { state: readonly(state), initialize, signIn, signOut, isAdmin: () => state.profile?.role === 'admin' } }
