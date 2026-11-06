-- BYA3A commerce migration. Apply after 001 and 002 in Supabase SQL Editor.
-- Keep original data; no destructive table resets.
ALTER TABLE public.order_records ADD COLUMN IF NOT EXISTS payment_method text NOT NULL DEFAULT 'myfatoorah';
ALTER TABLE public.order_records ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'unpaid';
ALTER TABLE public.order_records ADD COLUMN IF NOT EXISTS delivery_fee numeric(12,3) NOT NULL DEFAULT 0;
ALTER TABLE public.order_records ADD COLUMN IF NOT EXISTS delivery_area text;
ALTER TABLE public.order_records ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.order_records ADD COLUMN IF NOT EXISTS is_test boolean NOT NULL DEFAULT false;
ALTER TABLE public.order_records ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.order_records DROP CONSTRAINT IF EXISTS order_records_status_check;
ALTER TABLE public.order_records ADD CONSTRAINT order_records_status_check CHECK(status IN ('pending_payment','pending','confirmed','preparing','out_for_delivery','delivered','cancelled','refunded','paid'));
ALTER TABLE public.order_records ADD CONSTRAINT order_payment_method_check CHECK(payment_method IN ('cod','myfatoorah'));
ALTER TABLE public.order_records ADD CONSTRAINT order_payment_status_check CHECK(payment_status IN ('unpaid','paid','refunded'));
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS sku text;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS featured boolean NOT NULL DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS products_sku_unique ON public.products(sku) WHERE sku IS NOT NULL;
CREATE TABLE IF NOT EXISTS public.product_images (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,url text NOT NULL,sort_order integer NOT NULL DEFAULT 0,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.product_categories (product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,category_id uuid NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,PRIMARY KEY(product_id,category_id));
CREATE TABLE IF NOT EXISTS public.delivery_areas (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name_ar text NOT NULL UNIQUE,fee numeric(12,3) NOT NULL DEFAULT 0 CHECK(fee>=0),enabled boolean NOT NULL DEFAULT true,sort_order integer NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS public.coupons (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),code text NOT NULL UNIQUE,discount_percent integer NOT NULL CHECK(discount_percent BETWEEN 1 AND 100),active boolean NOT NULL DEFAULT true,expires_at timestamptz,usage_limit integer,used_count integer NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS public.site_banners (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),title text NOT NULL,image_url text,link_url text,active boolean NOT NULL DEFAULT true,sort_order integer NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS public.staff_permissions (user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,permissions text[] NOT NULL DEFAULT '{}');
CREATE TABLE IF NOT EXISTS public.order_events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES public.order_records(id) ON DELETE CASCADE,actor_id uuid REFERENCES auth.users(id),event text NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_events ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA public TO authenticated,anon;
GRANT SELECT ON public.admin_users TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.products,public.categories,public.product_images,public.product_categories,public.delivery_areas,public.coupons,public.site_banners TO authenticated;
GRANT SELECT ON public.product_images,public.product_categories,public.delivery_areas,public.site_banners TO anon;
GRANT SELECT ON public.staff_permissions,public.order_events,public.order_records,public.order_lines TO authenticated;
GRANT INSERT,UPDATE,DELETE ON public.staff_permissions TO authenticated;
CREATE OR REPLACE FUNCTION public.has_staff_permission(p text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT public.is_admin() OR EXISTS(SELECT 1 FROM public.admin_users a JOIN public.staff_permissions sp ON sp.user_id=a.user_id WHERE a.user_id=auth.uid() AND a.role='staff' AND p=ANY(sp.permissions))
$$;
GRANT EXECUTE ON FUNCTION public.has_staff_permission(text) TO authenticated;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='product_images' AND policyname='public view images') THEN CREATE POLICY "public view images" ON public.product_images FOR SELECT TO anon,authenticated USING(true); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='product_images' AND policyname='admin edit images') THEN CREATE POLICY "admin edit images" ON public.product_images FOR ALL TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='product_categories' AND policyname='public view product categories') THEN CREATE POLICY "public view product categories" ON public.product_categories FOR SELECT TO anon,authenticated USING(true); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='product_categories' AND policyname='admin edit product categories') THEN CREATE POLICY "admin edit product categories" ON public.product_categories FOR ALL TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='delivery_areas' AND policyname='public view delivery areas') THEN CREATE POLICY "public view delivery areas" ON public.delivery_areas FOR SELECT TO anon,authenticated USING(enabled OR public.is_admin()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='delivery_areas' AND policyname='admin edit delivery areas') THEN CREATE POLICY "admin edit delivery areas" ON public.delivery_areas FOR ALL TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='coupons' AND policyname='admin coupons') THEN CREATE POLICY "admin coupons" ON public.coupons FOR ALL TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='site_banners' AND policyname='public view banners') THEN CREATE POLICY "public view banners" ON public.site_banners FOR SELECT TO anon,authenticated USING(active OR public.is_admin()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='site_banners' AND policyname='admin edit banners') THEN CREATE POLICY "admin edit banners" ON public.site_banners FOR ALL TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='staff_permissions' AND policyname='owner manage permissions') THEN CREATE POLICY "owner manage permissions" ON public.staff_permissions FOR ALL TO authenticated USING(public.is_owner()) WITH CHECK(public.is_owner()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='staff_permissions' AND policyname='staff view own permissions') THEN CREATE POLICY "staff view own permissions" ON public.staff_permissions FOR SELECT TO authenticated USING(user_id=auth.uid()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='order_events' AND policyname='admin view events') THEN CREATE POLICY "admin view events" ON public.order_events FOR SELECT TO authenticated USING(public.is_admin()); END IF;
END $$;
-- Order placement: SECURITY DEFINER atomically validates catalog, deducts stock and writes order+lines.
-- The caller cannot set prices, status or payment flags.
CREATE OR REPLACE FUNCTION public.place_cod_order(p_items jsonb,p_name text,p_mobile text,p_address text,p_area_id uuid DEFAULT NULL,p_notes text DEFAULT '',p_is_test boolean DEFAULT false)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_id uuid;v_subtotal numeric(12,3):=0;v_fee numeric(12,3):=0;v_item jsonb;v_product record;v_qty int;v_id_product uuid;v_count int:=0;v_area text;v_actor uuid;
BEGIN
 IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'السلة غير صالحة'; END IF;
 IF length(trim(coalesce(p_name,''))) NOT BETWEEN 2 AND 120 OR coalesce(p_mobile,'') !~ '^[0-9]{8}$' OR length(trim(coalesce(p_address,''))) NOT BETWEEN 10 AND 500 THEN RAISE EXCEPTION 'بيانات التوصيل غير صالحة'; END IF;
 IF length(coalesce(p_notes,''))>500 THEN RAISE EXCEPTION 'الملاحظات طويلة'; END IF;
 IF p_area_id IS NOT NULL THEN SELECT name_ar,fee INTO v_area,v_fee FROM public.delivery_areas WHERE id=p_area_id AND enabled=true; IF NOT FOUND THEN RAISE EXCEPTION 'منطقة التوصيل غير متاحة'; END IF; END IF;
 -- Sort and lock all product rows in consistent order to prevent overselling and deadlocks.
 FOR v_product IN SELECT p.id,p.price,p.stock,p.name_ar,p.published FROM public.products p WHERE p.id IN (SELECT DISTINCT (x->>'id')::uuid FROM jsonb_array_elements(p_items) x WHERE (x->>'id') ~ '^[0-9a-fA-F-]{36}$') ORDER BY p.id FOR UPDATE LOOP
   SELECT sum((x->>'qty')::int),count(*) INTO v_qty,v_count FROM jsonb_array_elements(p_items) x WHERE x->>'id'=v_product.id::text;
   IF v_qty IS NULL OR v_qty<1 OR v_qty>99 OR NOT v_product.published OR v_product.stock<v_qty OR v_product.price<=0 THEN RAISE EXCEPTION 'المنتج غير متوفر أو الكمية غير صالحة: %',v_product.name_ar; END IF;
   v_subtotal:=v_subtotal+v_product.price*v_qty;
 END LOOP;
 IF (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(p_items) x) <> (SELECT count(*) FROM public.products p WHERE p.id IN (SELECT DISTINCT (x->>'id')::uuid FROM jsonb_array_elements(p_items) x WHERE (x->>'id') ~ '^[0-9a-fA-F-]{36}$')) THEN RAISE EXCEPTION 'بعض المنتجات غير متوفرة'; END IF;
 IF v_subtotal<=0 OR v_subtotal>100000 THEN RAISE EXCEPTION 'قيمة الطلب غير صالحة'; END IF;
 v_actor:=auth.uid();
 INSERT INTO public.order_records(customer_id,status,total,customer_name,customer_mobile,delivery_address,payment_method,payment_status,delivery_fee,delivery_area,notes,is_test)
 VALUES(v_actor,'pending',v_subtotal+v_fee,trim(p_name),p_mobile,trim(p_address),'cod','unpaid',v_fee,v_area,trim(coalesce(p_notes,'')),p_is_test) RETURNING id INTO v_id;
 FOR v_product IN SELECT p.id,p.price,p.stock FROM public.products p WHERE p.id IN (SELECT DISTINCT (x->>'id')::uuid FROM jsonb_array_elements(p_items) x) ORDER BY p.id LOOP
  SELECT sum((x->>'qty')::int) INTO v_qty FROM jsonb_array_elements(p_items) x WHERE x->>'id'=v_product.id::text;
  INSERT INTO public.order_lines(order_id,product_id,quantity,unit_price) VALUES(v_id,v_product.id,v_qty,v_product.price);
  UPDATE public.products SET stock=stock-v_qty,updated_at=now() WHERE id=v_product.id;
 END LOOP;
 INSERT INTO public.order_events(order_id,actor_id,event) VALUES(v_id,v_actor,'created_cod');
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.place_cod_order(jsonb,text,text,text,uuid,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_cod_order(jsonb,text,text,text,uuid,text,boolean) TO anon,authenticated;
-- Admin order transitions. Stock is restored once when cancelled, not for delivered orders.
CREATE OR REPLACE FUNCTION public.manage_cod_order(p_order_id uuid,p_status text,p_paid boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_old text;v_method text;v_item record;
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'غير مصرح'; END IF;
 SELECT status,payment_method INTO v_old,v_method FROM public.order_records WHERE id=p_order_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'الطلب غير موجود'; END IF;
 IF v_method<>'cod' THEN RAISE EXCEPTION 'هذا الإجراء خاص بالدفع عند الاستلام'; END IF;
 IF p_status NOT IN ('pending','confirmed','preparing','out_for_delivery','delivered','cancelled') THEN RAISE EXCEPTION 'حالة غير صالحة'; END IF;
 IF v_old='cancelled' AND p_status<>'cancelled' THEN RAISE EXCEPTION 'لا يمكن إعادة فتح طلب ملغى'; END IF;
 IF v_old='delivered' AND p_status='cancelled' THEN RAISE EXCEPTION 'لا يمكن إلغاء طلب تم تسليمه'; END IF;
 IF p_status='cancelled' AND v_old<>'cancelled' THEN
  FOR v_item IN SELECT product_id,quantity FROM public.order_lines WHERE order_id=p_order_id AND product_id IS NOT NULL LOOP
   UPDATE public.products SET stock=stock+v_item.quantity,updated_at=now() WHERE id=v_item.product_id;
  END LOOP;
 END IF;
 UPDATE public.order_records SET status=p_status,payment_status=CASE WHEN p_paid AND p_status='delivered' THEN 'paid' ELSE payment_status END,updated_at=now() WHERE id=p_order_id;
 INSERT INTO public.order_events(order_id,actor_id,event) VALUES(p_order_id,auth.uid(),'status:'||p_status);
END $$;
REVOKE ALL ON FUNCTION public.manage_cod_order(uuid,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.manage_cod_order(uuid,text,boolean) TO authenticated;
-- Public catalog RLS evaluates is_admin() for anonymous visitors: function safely returns false.
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='order_records' AND policyname='customer read own orders') THEN
 CREATE POLICY "customer read own orders" ON public.order_records FOR SELECT TO authenticated USING(customer_id=auth.uid()); END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='order_lines' AND policyname='customer read own order lines') THEN
 CREATE POLICY "customer read own order lines" ON public.order_lines FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.order_records o WHERE o.id=order_id AND o.customer_id=auth.uid())); END IF;
END $$;
-- Restrict COD order creation to expected input formats; browser checkout is the public entry point.
