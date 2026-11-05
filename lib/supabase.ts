import { createClient } from '@supabase/supabase-js'
export function db(){const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!key)return null;return createClient(url,key)}
export type Product={id:string;name_ar:string;description_ar:string|null;price:number;compare_at:number|null;stock:number;image_url:string|null;category_id:string|null;published:boolean;created_at:string}
