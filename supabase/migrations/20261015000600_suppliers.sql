-- ============================================================================
-- Supplier integration: make sync and fulfilment idempotent, and let a line
-- defer (retry) instead of being refunded when the failure is ours, not the
-- buyer's.
--
-- The distinction matters: "insufficient supplier balance" must not refund a
-- buyer who paid correctly, and must not silently drop the order either.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Products owned by a supplier sync
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists supplier_id bigint references public.suppliers (id) on delete set null,
  add column if not exists supplier_game_code text;

create unique index if not exists products_supplier_game_idx
  on public.products (supplier_id, supplier_game_code)
  where supplier_id is not null and supplier_game_code is not null;

-- ---------------------------------------------------------------------------
-- Attempt tracking on the job row
-- ---------------------------------------------------------------------------
alter table public.order_items
  add column if not exists supplier_attempts integer not null default 0,
  add column if not exists supplier_last_error text,
  add column if not exists supplier_next_attempt_at timestamptz;

-- ---------------------------------------------------------------------------
-- Known suppliers. is_active stays false until a key exists.
-- ---------------------------------------------------------------------------
insert into public.suppliers (code, name, base_url, is_active) values
  ('bay2game', 'Bay2Game', 'https://api.bay2game.xyz/api', false),
  ('kasplay',  'KAS Play', 'https://reseller-api.kasplay.kascambodia.com/api/v1', false)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- supplier_pending_items: skip lines that are backing off or exhausted, and
-- hand the worker everything it needs including attempt count.
-- ---------------------------------------------------------------------------
drop function if exists public.supplier_pending_items(integer);

create or replace function public.supplier_pending_items(p_limit integer default 20)
returns table (
  item_id         bigint,
  order_id        uuid,
  order_no        text,
  variant_id      bigint,
  sku             text,
  qty             integer,
  customer_fields jsonb,
  supplier_code   text,
  supplier_sku    text,
  cost_usd        numeric,
  attempts        integer
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
    coalesce(ss.cost_usd, v.cost_usd),
    oi.supplier_attempts
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  join public.product_variants v on v.id = oi.variant_id
  join public.products p on p.id = v.product_id
  left join public.supplier_skus ss on ss.variant_id = v.id and ss.is_active
  left join public.suppliers s on s.id = ss.supplier_id and s.is_active
 where oi.delivery_status = 'pending'
   and p.kind = 'auto_topup'
   and o.status in ('paid', 'delivering')
   and oi.supplier_attempts < 5
   and (oi.supplier_next_attempt_at is null or oi.supplier_next_attempt_at <= now())
 order by oi.id
 limit p_limit;
$$;

revoke execute on function public.supplier_pending_items(integer)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- supplier_note_failure: record an attempt without moving money.
-- Used when the failure is transient or the supplier account is at fault
-- (out of balance, upstream 500). The line stays pending and retries.
-- ---------------------------------------------------------------------------
create or replace function public.supplier_note_failure(
  p_item_id bigint,
  p_error   text,
  p_retry_in_minutes integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_attempts integer;
begin
  update public.order_items
     set supplier_attempts = supplier_attempts + 1,
         supplier_last_error = left(p_error, 500),
         supplier_next_attempt_at = now() + make_interval(mins => p_retry_in_minutes)
   where id = p_item_id
  returning supplier_attempts into v_attempts;

  if not found then
    raise exception 'item_not_found';
  end if;

  -- Out of retries: this is now a staff problem, so leave a marker rather than
  -- refunding a buyer whose order was never actually attempted.
  if v_attempts >= 5 then
    update public.order_items
       set delivery_status = 'manual_waiting'
     where id = p_item_id;
  end if;

  return jsonb_build_object('ok', true, 'attempts', v_attempts);
end;
$$;

revoke execute on function public.supplier_note_failure(bigint, text, integer)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- supplier_upsert_catalogue: one call per game, so a sync is atomic per game
-- and cannot leave a half-linked product behind.
-- ---------------------------------------------------------------------------
create or replace function public.supplier_upsert_catalogue(
  p_supplier_code text,
  p_game_code     text,
  p_name          text,
  p_image_url     text,
  p_summary       text,
  p_required_fields jsonb,      -- ["userid","serverid"]
  p_products      jsonb         -- [{ product_code, name, price_usd }]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_supplier public.suppliers;
  v_product_id bigint;
  v_slug text;
  v_item jsonb;
  v_variant_id bigint;
  v_upserted integer := 0;
begin
  select * into v_supplier from public.suppliers where code = p_supplier_code;
  if not found then
    raise exception 'unknown_supplier' using detail = p_supplier_code;
  end if;

  v_slug := p_supplier_code || '-' || p_game_code;

  insert into public.products (
    slug, name_km, name_en, summary_km, summary_en, image_url, kind,
    requires_fields, supplier_id, supplier_game_code, is_active, sort_order
  ) values (
    v_slug, p_name, p_name, p_summary, p_summary, p_image_url, 'auto_topup',
    coalesce(p_required_fields, '[]'::jsonb), v_supplier.id, p_game_code, true, 1000
  )
  on conflict (slug) do update
    set name_km       = excluded.name_km,
        name_en       = excluded.name_en,
        summary_km    = excluded.summary_km,
        summary_en    = excluded.summary_en,
        image_url     = coalesce(excluded.image_url, public.products.image_url),
        requires_fields = excluded.requires_fields,
        supplier_id   = excluded.supplier_id,
        supplier_game_code = excluded.supplier_game_code,
        updated_at    = now()
  returning id into v_product_id;

  for v_item in select * from jsonb_array_elements(p_products)
  loop
    insert into public.product_variants (
      product_id, sku, label_km, label_en, price_usd, cost_usd,
      stock_mode, min_qty, max_qty, is_active, sort_order
    ) values (
      v_product_id,
      (v_item ->> 'product_code'),
      (v_item ->> 'name'),
      (v_item ->> 'name'),
      -- The supplier price is cost. Retail is set by staff afterwards; until
      -- then it is cost, so an unpriced SKU can never be sold at a loss.
      round((v_item ->> 'price_usd')::numeric, 2),
      round((v_item ->> 'price_usd')::numeric, 2),
      'unlimited', 1, 50, true, coalesce((v_item ->> 'sort')::int, 0)
    )
    on conflict (sku) do update
      set label_km  = excluded.label_km,
          label_en  = excluded.label_en,
          cost_usd  = excluded.cost_usd,
          is_active = true,
          product_id = excluded.product_id
    returning id into v_variant_id;

    insert into public.supplier_skus (
      supplier_id, variant_id, supplier_sku, cost_usd, is_active, last_synced_at, last_cost_usd
    ) values (
      v_supplier.id, v_variant_id, (v_item ->> 'product_code'),
      round((v_item ->> 'price_usd')::numeric, 2), true, now(),
      round((v_item ->> 'price_usd')::numeric, 2)
    )
    on conflict (supplier_id, variant_id, supplier_sku) do update
      set cost_usd       = excluded.cost_usd,
          last_cost_usd  = excluded.last_cost_usd,
          last_synced_at = now(),
          is_active      = true;

    v_upserted := v_upserted + 1;
  end loop;

  return jsonb_build_object(
    'product_id', v_product_id,
    'slug', v_slug,
    'variants_synced', v_upserted
  );
end;
$$;

revoke execute on function public.supplier_upsert_catalogue(text, text, text, text, text, jsonb, jsonb)
  from public, anon, authenticated;
