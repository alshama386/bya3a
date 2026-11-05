# بياعة — BYA3A.com

## Status — read before deployment

**This is a real-code starter implementation, NOT the completed production store.** The project has an Arabic responsive storefront, actual Supabase-backed product catalog, cart stored in the browser, authentication form, and role-protected product publishing dashboard. The approved brand artwork is included. **Checkout intentionally cannot accept orders/payments** until a real payment provider and secure transaction handling are integrated. iOS/Android native projects, WhatsApp, image search, rewards, customer service, shipping integrations, and other approved requirements are **not implemented**. Do not advertise or launch it as a finished store.

## Step 1 — GitHub

Unzip and upload all files/folders to the root of a new private GitHub repository (do not upload the ZIP as a single file). The Next.js app is at repository root.

## Step 2 — Vercel

Import repository into Vercel. Framework: Next.js; build command: `npm run build`. Add environment variables `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` once Supabase is ready. Redeploy. Domain configuration can be done separately; point DNS to the values provided by Vercel, not guessed records.

## Step 3 — Supabase

Create a Supabase project, open SQL Editor, run `supabase/migrations/001_initial.sql` once. In Supabase Auth create/sign up the owner account **alshama386@gmail.com** with a strong password. Email alone does not grant admin rights. In SQL Editor, after user creation, run:

```sql
insert into public.admin_users (user_id, role)
select id, 'owner' from auth.users
where email = 'alshama386@gmail.com'
on conflict (user_id) do update set role='owner';
```

Do not expose Supabase `service_role` key to the browser or in GitHub. Use only public anon key in NEXT_PUBLIC variables. Configure authentication email confirmations and redirect URLs in Supabase for your deployment. To add product photos, this initial dashboard accepts an image URL; direct file upload is not yet implemented.

## Local run

Node 20+ recommended. Copy `.env.example` to `.env.local`, fill values, run `npm install` then `npm run dev`.

## Safety / launch checklist

- Implement secure gateway payment integration and verify webhook signatures, amounts and idempotency server-side.
- Add transactional stock reservation/decrement and prevent overselling.
- Complete addresses, delivery regions, refunds, tax/accounting, legal pages, privacy/consent and customer workflows.
- Build native iOS/Android applications and test store compliance.
- Implement all other approved features; perform security, accessibility and functional tests.
- Ensure Supabase RLS remains enabled. Use service credentials only in secure server contexts.

## Brand reference

`public/brand/approved-reference.png` is the user's approved composite visual. The supplied four original logo/mascot images are under `public/brand/`.
