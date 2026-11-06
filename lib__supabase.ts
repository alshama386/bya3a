import { createClient, type SupabaseClient } from '@supabase/supabase-js';
let singleton: SupabaseClient | null = null;
export function db() {
  if (singleton) return singleton;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  singleton = createClient(url, key, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: 'bya3a-auth' }
  });
  return singleton;
}
export type Product = {id:string;name_ar:string;description_ar:string|null;price:number;compare_at:number|null;stock:number;image_url:string|null;category_id:string|null;published:boolean;created_at:string};
