-- ============================================================================
-- RLS, grants and access helpers
-- Rule of thumb: the catalogue is public, everything transactional is own-row,
-- the stock vault and supplier config are service-role only.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helpers. security definer + stable so they can be used inside policies.
-- ---------------------------------------------------------------------------
create or replace function public.current_role_is(target public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = any (target)
      and p.is_blocked = false
  );
$$;

create or replace function public.is_staff()
returns boolean
language sql stable
security definer
set search_path = ''
as $$ select public.current_role_is(array['staff','admin']::public.app_role[]); $$;

create or replace function public.is_admin()
returns boolean
language sql stable
security definer
set search_path = ''
as $$ select public.current_role_is(array['admin']::public.app_role[]); $$;

revoke all on function public.current_role_is(public.app_role[]) from public;
grant execute on function public.current_role_is(public.app_role[]) to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere in public
-- ---------------------------------------------------------------------------
do $$
declare t record;
begin
  for t in
    select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security', t.tablename);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Default privileges: anon/authenticated get nothing unless granted below.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on schema private from anon, authenticated;
revoke all on all tables in schema private from anon, authenticated;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
grant select on public.profiles to authenticated;
-- Column-level: a customer may edit these three columns, nothing else.
grant update (display_name, phone, locale) on public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy profiles_admin_all on public.profiles
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- settings: locked. Storefront reads public_settings instead.
-- ---------------------------------------------------------------------------
create policy settings_admin_all on public.settings
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant select on public.public_settings to anon, authenticated;
grant select on public.profile_names to anon, authenticated;
grant select on public.variant_stock to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------
grant select on public.categories to anon, authenticated;
grant select on public.products to anon, authenticated;
grant select on public.product_variants to anon, authenticated;

create policy categories_public_read on public.categories
  for select to anon, authenticated
  using (is_active = true);

create policy products_public_read on public.products
  for select to anon, authenticated
  using (is_active = true);

create policy variants_public_read on public.product_variants
  for select to anon, authenticated
  using (is_active = true);

create policy categories_admin_all on public.categories
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy products_admin_all on public.products
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy variants_admin_all on public.product_variants
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

-- Sequences for staff inserts
grant usage, select on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- Orders / items / payments: own row only, writes go through RPC
-- ---------------------------------------------------------------------------
grant select on public.orders to authenticated;
grant select on public.order_items to authenticated;
grant select on public.payments to authenticated;
grant select on public.wallet_transactions to authenticated;
grant select on public.reviews to anon, authenticated;
-- The insert policy below is useless without the matching table grant.
grant insert on public.reviews to authenticated;

create policy orders_select_own on public.orders
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_staff());

create policy order_items_select_own on public.order_items
  for select to authenticated
  using (
    public.is_staff()
    or exists (
      select 1 from public.orders o
      where o.id = order_items.order_id and o.user_id = (select auth.uid())
    )
  );

create policy payments_select_own on public.payments
  for select to authenticated
  using (
    public.is_staff()
    or exists (
      select 1 from public.orders o
      where o.id = payments.order_id and o.user_id = (select auth.uid())
    )
  );

create policy wallet_tx_select_own on public.wallet_transactions
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_staff());

-- ---------------------------------------------------------------------------
-- Reviews: public read of approved ones, write only for a real purchase
-- ---------------------------------------------------------------------------
create policy reviews_public_read on public.reviews
  for select to anon, authenticated
  using (is_approved = true or user_id = (select auth.uid()));

create policy reviews_insert_own on public.reviews
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and is_approved = false
    and coin_rewarded = false
    and exists (
      select 1
      from public.orders o
      join public.order_items oi on oi.order_id = o.id
      join public.product_variants v on v.id = oi.variant_id
      where o.user_id = (select auth.uid())
        and o.status = 'delivered'
        and v.product_id = reviews.product_id
    )
  );

create policy reviews_staff_all on public.reviews
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

-- ---------------------------------------------------------------------------
-- Coupons: never listable, validated through an RPC
-- ---------------------------------------------------------------------------
create policy coupons_staff_all on public.coupons
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy coupon_redemptions_staff_all on public.coupon_redemptions
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

-- ---------------------------------------------------------------------------
-- Suppliers + audit: staff only, secrets stay in private schema
-- ---------------------------------------------------------------------------
create policy suppliers_staff_all on public.suppliers
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy supplier_skus_staff_all on public.supplier_skus
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy audit_staff_read on public.audit_log
  for select to authenticated using (public.is_staff());
