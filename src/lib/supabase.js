import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabaseConfigured = Boolean(url && key)
if (!url || !key) console.warn('Manjka Supabase konfiguracija. Kopirajte .env.example v .env.')
export const supabase = createClient(url || 'https://placeholder.supabase.co', key || 'placeholder')
