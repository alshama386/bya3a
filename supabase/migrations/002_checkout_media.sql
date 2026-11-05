-- Run once in Supabase SQL Editor after 001_initial.sql
alter table public.order_records add column if not exists customer_name text;
alter table public.order_records add column if not exists customer_mobile text;
alter table public.order_records add column if not exists delivery_address text;
alter table public.order_records add column if not exists payment_invoice_id text;
create unique index if not exists order_payment_invoice_unique on public.order_records(payment_invoice_id) where payment_invoice_id is not null;
-- Keep order writes server-side with the service role. Never grant order INSERT to anon.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy "product images publicly viewable" on storage.objects for select to anon,authenticated using(bucket_id='product-images');
create policy "admins upload product images" on storage.objects for insert to authenticated with check(bucket_id='product-images' and public.is_admin());
create policy "admins update product images" on storage.objects for update to authenticated using(bucket_id='product-images' and public.is_admin()) with check(bucket_id='product-images' and public.is_admin());
create policy "admins delete product images" on storage.objects for delete to authenticated using(bucket_id='product-images' and public.is_admin());
