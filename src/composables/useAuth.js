import { reactive, readonly } from 'vue'
import { supabase } from '../lib/supabase'
const state = reactive({ ready: false, user: null, profile: null })
async function loadProfile() { if (!state.user) { state.profile = null; return }; const { data } = await supabase.from('profiles').select('*').eq('id', state.user.id).single(); state.profile = data }
async function initialize() { const { data } = await supabase.auth.getSession(); state.user = data.session?.user || null; await loadProfile(); state.ready = true; supabase.auth.onAuthStateChange(async (_e, session) => { state.user = session?.user || null; await loadProfile() }) }
async function signIn(email, password) { const { error } = await supabase.auth.signInWithPassword({ email, password }); if (error) throw error; await loadProfile() }
async function signOut() { await supabase.auth.signOut(); state.user = null; state.profile = null }
export function useAuth() { return { state: readonly(state), initialize, signIn, signOut, isAdmin: () => state.profile?.role === 'admin' } }
