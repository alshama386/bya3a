-- BYA3A: execute in Supabase SQL editor after creating project.
create extension if not exists pgcrypto;
create table if not exists public.admin_users (user_id uuid primary key references auth.users(id) on delete cascade, role text not null check(role in ('owner','admin','staff')), created_at timestamptz default now());
create table if not exists public.categories(id uuid primary key default gen_random_uuid(),name_ar text not null,parent_id uuid references public.categories(id),sort_order int not null default 0,visible boolean not null default true);
create table if not exists public.products(id uuid primary key default gen_random_uuid(),name_ar text not null,description_ar text,price numeric(12,3) not null check(price>=0),compare_at numeric(12,3) check(compare_at is null or compare_at>=0),stock integer not null default 0 check(stock>=0),image_url text,category_id uuid references public.categories(id),published boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.order_records(id uuid primary key default gen_random_uuid(),customer_id uuid references auth.users(id),status text not null default 'pending_payment' check(status in ('pending_payment','paid','preparing','out_for_delivery','delivered','cancelled','refunded')),total numeric(12,3) not null check(total>=0),created_at timestamptz not null default now());
create table if not exists public.order_lines(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.order_records(id),product_id uuid references public.products(id),quantity integer not null check(quantity>0),unit_price numeric(12,3) not null check(unit_price>=0));
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.admin_users where user_id=(select auth.uid()) and role in ('owner','admin'))$$;
create or replace function public.is_owner() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.admin_users where user_id=(select auth.uid()) and role='owner')$$;
alter table public.admin_users enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.order_records enable row level security;
alter table public.order_lines enable row level security;
create policy "admins read own admin role" on public.admin_users for select to authenticated using (user_id=(select auth.uid()) or public.is_owner());
create policy "owner manages roles" on public.admin_users for all to authenticated using(public.is_owner()) with check(public.is_owner());
create policy "public categories" on public.categories for select to anon,authenticated using(visible or public.is_admin());
create policy "admins categories" on public.categories for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "public products" on public.products for select to anon,authenticated using(published or public.is_admin());
create policy "admins insert products" on public.products for insert to authenticated with check(public.is_admin());
create policy "admins update products" on public.products for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins delete products" on public.products for delete to authenticated using(public.is_admin());
create policy "admins read orders" on public.order_records for select to authenticated using(public.is_admin());
create policy "customer read own orders" on public.order_records for select to authenticated using(customer_id=(select auth.uid()));
create policy "admins read order lines" on public.order_lines for select to authenticated using(public.is_admin());
-- IMPORTANT: no public order INSERT policy. Checkout must be implemented with verified payment server-side.
-- Owner bootstrap: create user through Supabase Auth first, then run the SQL in README.
