-- ============================================================================
-- Closes the gaps found in the first audit:
--   1. wallet had no way to be funded
--   2. expire_stale_orders() and refresh_product_ratings() were never scheduled
--   3. reviews could never be approved, so ratings stayed at zero
--   4. auto_topup items had no worker to fulfil them
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Wallet top-up
--
-- A top-up reuses the whole order/payment pipeline: create a pending order with
-- kind='wallet_topup', pay it by KHQR, and mark_order_paid credits the wallet
-- instead of delivering goods.
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists kind text not null default 'purchase'
  check (kind in ('purchase', 'wallet_topup'));

create index if not exists orders_kind_idx on public.orders (kind) where kind = 'wallet_topup';

alter table public.settings
  add column if not exists topup_min_usd numeric(12, 2) not null default 1,
  add column if not exists topup_max_usd numeric(12, 2) not null default 1000;

create or replace view public.public_settings as
select
  id,
  site_name,
  support_telegram,
  support_email,
  usd_to_khr,
  order_ttl_minutes,
  khqr_account_id,
  khqr_merchant_name,
  khqr_merchant_city,
  is_maintenance,
  topup_min_usd,
  topup_max_usd
from public.settings;

grant select on public.public_settings to anon, authenticated;

create or replace function public.create_wallet_topup(
  p_amount_usd numeric,
  p_email      text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user     uuid := (select auth.uid());
  v_profile  public.profiles;
  v_settings public.settings;
  v_order_id uuid;
  v_order_no text;
begin
  if v_user is null then
    raise exception 'auth_required';
  end if;

  select * into v_profile from public.profiles where id = v_user;
  if v_profile.is_blocked then
    raise exception 'account_blocked';
  end if;

  select * into v_settings from public.settings where id;

  -- Round to cents so the KHQR amount always matches what PayWay is told.
  p_amount_usd := round(coalesce(p_amount_usd, 0), 2);

  if p_amount_usd < v_settings.topup_min_usd then
    raise exception 'topup_below_minimum'
      using detail = v_settings.topup_min_usd::text;
  end if;

  if p_amount_usd > v_settings.topup_max_usd then
    raise exception 'topup_above_maximum'
      using detail = v_settings.topup_max_usd::text;
  end if;

  v_order_no := private.new_order_no();

  insert into public.orders (
    order_no, user_id, status, kind, contact_email,
    subtotal_usd, discount_usd, total_usd, expires_at
  ) values (
    v_order_no, v_user, 'pending', 'wallet_topup', p_email,
    p_amount_usd, 0, p_amount_usd,
    now() + make_interval(mins => v_settings.order_ttl_minutes)
  ) returning id into v_order_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'total_usd', p_amount_usd,
    'expires_in_minutes', v_settings.order_ttl_minutes
  );
end;
$$;

grant execute on function public.create_wallet_topup(numeric, text) to authenticated;

-- ---------------------------------------------------------------------------
-- mark_order_paid: credit top-ups instead of delivering goods
-- ---------------------------------------------------------------------------
create or replace function public.mark_order_paid(
  p_order_id      uuid,
  p_provider      public.payment_provider,
  p_provider_ref  text default null,
  p_payway_method text default null,
  p_raw           jsonb default null,
  p_amount_khr    numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
  v_bal   numeric(12, 2);
begin
  select * into v_order from public.orders where id = p_order_id for update;

  if not found then
    raise exception 'order_not_found';
  end if;

  if v_order.status not in ('pending', 'paid', 'delivering', 'delivered') then
    return jsonb_build_object('ok', false, 'status', v_order.status);
  end if;

  if p_provider_ref is not null then
    insert into public.payments (
      order_id, provider, status, amount_usd, amount_khr,
      provider_ref, payway_method, raw_payload, verified_at
    ) values (
      p_order_id, p_provider, 'succeeded', v_order.total_usd, p_amount_khr,
      p_provider_ref, p_payway_method, p_raw, now()
    )
    on conflict (provider, provider_ref) where provider_ref is not null
    do update set status = 'succeeded', verified_at = now(), raw_payload = excluded.raw_payload;
  end if;

  -- Idempotency: only the transition out of 'pending' moves money or stock.
  if v_order.status = 'pending' then
    update public.orders set status = 'paid', paid_at = now() where id = p_order_id;

    if v_order.coupon_code is not null then
      update public.coupons
         set used_count = used_count + 1
       where upper(code) = upper(v_order.coupon_code);

      insert into public.coupon_redemptions (coupon_id, user_id, order_id, amount_usd)
      select c.id, v_order.user_id, p_order_id, v_order.discount_usd
        from public.coupons c
       where upper(c.code) = upper(v_order.coupon_code)
      on conflict do nothing;
    end if;

    if v_order.kind = 'wallet_topup' then
      v_bal := private.credit_wallet(
        v_order.user_id, v_order.total_usd, 'topup', p_order_id,
        'topup ' || v_order.order_no
      );

      update public.orders
         set status = 'delivered', delivered_at = now()
       where id = p_order_id;

      return jsonb_build_object('ok', true, 'status', 'delivered', 'wallet_balance', v_bal);
    end if;

    perform private.deliver_order(p_order_id);
  end if;

  return jsonb_build_object('ok', true, 'status', 'paid');
end;
$$;

revoke execute on function public.mark_order_paid(uuid, public.payment_provider, text, text, jsonb, numeric)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2 + 3. Review approval, and ratings that actually move
-- ---------------------------------------------------------------------------
create or replace function public.admin_review_set_approved(
  p_review_id bigint,
  p_approved  boolean,
  p_reward_coins integer default 5
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_review public.reviews;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  update public.reviews
     set is_approved = p_approved
   where id = p_review_id
  returning * into v_review;

  if not found then
    raise exception 'review_not_found';
  end if;

  -- Pay the review reward once, and only for an approval.
  if p_approved and not v_review.coin_rewarded and p_reward_coins > 0 then
    update public.profiles
       set coins = coins + p_reward_coins
     where id = v_review.user_id;

    update public.reviews set coin_rewarded = true where id = p_review_id;
  end if;

  perform public.refresh_product_ratings();
end;
$$;

grant execute on function public.admin_review_set_approved(bigint, boolean, integer) to authenticated;

-- Rating drift is otherwise silent, so keep it refresher-driven.
create or replace function public.refresh_all_product_ratings()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  update public.products p
     set rating_avg = coalesce(r.avg_rating, 0),
         rating_count = coalesce(r.cnt, 0)
    from (
      select product_id,
             round(avg(rating)::numeric, 2) as avg_rating,
             count(*)                        as cnt
        from public.reviews
       where is_approved
       group by product_id
    ) r
   where p.id = r.product_id;

  get diagnostics v_count = row_count;

  -- Products whose last review was unapproved keep a stale average; zero them.
  update public.products p
     set rating_avg = 0, rating_count = 0
   where not exists (
     select 1 from public.reviews rv
      where rv.product_id = p.id and rv.is_approved
   )
     and (p.rating_avg <> 0 or p.rating_count <> 0);

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Supplier worker: hand out auto_topup lines and take them back
-- ---------------------------------------------------------------------------
create or replace function public.supplier_pending_items(p_limit integer default 20)
returns table (
  item_id        bigint,
  order_id       uuid,
  order_no       text,
  variant_id     bigint,
  sku            text,
  qty            integer,
  customer_fields jsonb,
  supplier_code  text,
  supplier_sku   text,
  cost_usd       numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    oi.id,
    o.id,
    o.order_no,
    v.id,
    v.sku,
    oi.qty,
    o.customer_fields,
    s.code,
    ss.supplier_sku,
    coalesce(ss.cost_usd, v.cost_usd)
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  join public.product_variants v on v.id = oi.variant_id
  join public.products p on p.id = v.product_id
  left join public.supplier_skus ss on ss.variant_id = v.id and ss.is_active
  left join public.suppliers s on s.id = ss.supplier_id and s.is_active
 where oi.delivery_status = 'pending'
   and p.kind = 'auto_topup'
   and o.status in ('paid', 'delivering')
 order by oi.id
 limit p_limit;
$$;

revoke execute on function public.supplier_pending_items(integer) from public, anon, authenticated;

create or replace function public.supplier_complete_item(
  p_item_id   bigint,
  p_success   boolean,
  p_supplier_ref text default null,
  p_cost_usd  numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item    public.order_items;
  v_order   public.orders;
  v_pending integer;
  v_failed  integer;
begin
  select * into v_item from public.order_items where id = p_item_id for update;
  if not found then
    raise exception 'item_not_found';
  end if;

  select * into v_order from public.orders where id = v_item.order_id for update;

  if p_success then
    update public.order_items
       set delivery_status = 'delivered',
           delivered_at = now(),
           supplier_ref = coalesce(p_supplier_ref, supplier_ref),
           unit_cost_usd = coalesce(p_cost_usd, unit_cost_usd)
     where id = p_item_id;

    update public.products
       set sold_count = sold_count + v_item.qty
     where id = (select product_id from public.product_variants where id = v_item.variant_id);
  else
    update public.order_items
       set delivery_status = 'failed',
           supplier_ref = coalesce(p_supplier_ref, supplier_ref)
     where id = p_item_id;

    -- The buyer paid for something we cannot deliver, so return it to their
    -- wallet rather than leaving them to open a support ticket.
    perform private.credit_wallet(
      v_order.user_id, v_item.line_total_usd, 'refund', v_order.id,
      'refund ' || v_order.order_no || ' (' || v_item.product_name || ')'
    );
  end if;

  select
    count(*) filter (where delivery_status = 'pending'),
    count(*) filter (where delivery_status = 'failed')
    into v_pending, v_failed
    from public.order_items where order_id = v_order.id;

  if v_pending = 0 then
    update public.orders
       set status = case
                      when v_failed > 0 then 'failed'::public.order_status
                      else 'delivered'::public.order_status
                    end,
           delivered_at = case when v_failed = 0 then now() else delivered_at end
     where id = v_order.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'order_status', (select status from public.orders where id = v_order.id),
    'refunded_usd', case when p_success then 0 else v_item.line_total_usd end
  );
end;
$$;

revoke execute on function public.supplier_complete_item(bigint, boolean, text, numeric)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2 (cont). Schedule the housekeeping that was never running
--
-- This block must never fail the migration. Scheduling housekeeping is a nice
-- to have; creating the schema is not. On hosted Supabase cron.job is owned by
-- supabase_admin, so direct DML is refused and you must use cron.unschedule().
-- Each step is wrapped so a permission problem degrades to a notice.
-- ---------------------------------------------------------------------------
do $$
declare
  v_have_cron boolean := exists (select 1 from pg_namespace where nspname = 'cron');
begin
  if not v_have_cron then
    begin
      if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
        execute 'create extension pg_cron';
        v_have_cron := true;
      end if;
    exception when others then
      raise notice 'pg_cron could not be installed here (%); schedule manually', sqlerrm;
    end;
  end if;

  if not v_have_cron then
    raise notice 'pg_cron unavailable; schedule expire_stale_orders() and refresh_all_product_ratings() on the host';
    return;
  end if;

  -- Unschedule by name via the API, never by touching cron.job.
  begin
    perform cron.unschedule('ycp-expire-orders');
  exception when others then null;
  end;

  begin
    perform cron.unschedule('ycp-refresh-ratings');
  exception when others then null;
  end;

  begin
    perform cron.schedule('ycp-expire-orders', '*/2 * * * *',
                          'select public.expire_stale_orders()');
    perform cron.schedule('ycp-refresh-ratings', '*/30 * * * *',
                          'select public.refresh_all_product_ratings()');
    raise notice 'pg_cron jobs scheduled';
  exception
    when insufficient_privilege then
      raise notice 'pg_cron present but not schedulable by this role (%); schedule manually', sqlerrm;
    when others then
      raise notice 'pg_cron scheduling skipped: %', sqlerrm;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- Housekeeping: also void expired top-ups, and expose the sweep to staff
-- ---------------------------------------------------------------------------
create or replace function public.admin_run_housekeeping()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_expired integer;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  v_expired := public.expire_stale_orders();
  perform public.refresh_all_product_ratings();

  return jsonb_build_object('expired_orders', v_expired);
end;
$$;

grant execute on function public.admin_run_housekeeping() to authenticated;
