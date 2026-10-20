-- ============================================================================
-- Catalogue fit with the supplier: quantity, and SKUs the supplier dropped.
--
-- Two ways a synced catalogue could take money it cannot deliver on:
--
-- 1. QUANTITY. Sync wrote every variant as min_qty=1, max_qty=50. Bay2Game's
--    /create_order takes a product_code and buyer fields only — no quantity —
--    so a line for two would be delivered once. The adapter now declares
--    `supportsQuantity: false`, the sync passes `max_qty: 1`, and this function
--    stores it. create_order already validates qty against the variant's
--    min_qty/max_qty in Postgres, so the cap is enforced server-side even if a
--    client ignores it, and the quantity stepper disappears on its own.
--
-- 2. STALE SKUs. Sync only ever set is_active = true. A product the supplier
--    removed stayed sellable, so the buyer paid and the order could only be
--    refunded. A sync is now a snapshot: anything this supplier no longer
--    lists for the game is deactivated, and a game left with nothing on sale is
--    hidden instead of shown empty.
--
-- An empty product list is deliberately NOT a snapshot. A supplier having a bad
-- day, a rate limit answered with an empty body, or a game whose packages are
-- all inactive would otherwise empty the shop in one call. Nothing is
-- deactivated unless the pull actually returned products.
--
-- The body below carries forward the two behaviours earlier migrations added to
-- this same function — field normalisation (20261015000700) and an unpriced
-- SKU following the supplier's cost (20261015001300) — because plpgsql bodies
-- cannot be patched. Dropping either one silently breaks a tested guarantee;
-- `smoke.sql` checks both.
-- ============================================================================

create or replace function public.supplier_upsert_catalogue(
  p_supplier_code   text,
  p_game_code       text,
  p_name            text,
  p_image_url       text,
  p_summary         text,
  p_required_fields jsonb,      -- [{ key, label_km, label_en, placeholder }]
  p_products        jsonb       -- [{ product_code, name, price_usd, sort, max_qty }]
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
  v_fields jsonb;
  v_upserted integer := 0;
  v_deactivated integer := 0;
begin
  select * into v_supplier from public.suppliers where code = p_supplier_code;
  if not found then
    raise exception 'unknown_supplier' using detail = p_supplier_code;
  end if;

  v_slug := p_supplier_code || '-' || p_game_code;
  v_fields := public.supplier_field_definitions(p_required_fields);

  insert into public.products (
    slug, name_km, name_en, summary_km, summary_en, image_url, kind,
    requires_fields, supplier_id, supplier_game_code, is_active, sort_order
  ) values (
    v_slug, p_name, p_name, p_summary, p_summary, p_image_url, 'auto_topup',
    v_fields, v_supplier.id, p_game_code, true, 1000
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
        -- Deliberately NOT is_active = true. A product is activated when it is
        -- first synced, but from then on the switch belongs to staff: hiding a
        -- broken game must survive the next sync. A game this sync hides
        -- because the supplier dropped every package stays hidden too, so
        -- selling something undeliverable is never the automatic outcome.
        -- Staff re-enable it with admin_product_set_active once the supplier
        -- lists it again.
        updated_at    = now()
  returning id into v_product_id;

  for v_item in select * from jsonb_array_elements(coalesce(p_products, '[]'::jsonb))
  loop
    if coalesce(btrim(v_item ->> 'product_code'), '') = '' then
      raise exception 'product_missing_code'
        using detail = left(v_item::text, 200);
    end if;

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
      'unlimited',
      -- 50 is the default for a supplier whose API takes a quantity. A
      -- supplier that cannot is capped at one unit per line by the sync.
      coalesce((v_item ->> 'min_qty')::int, 1),
      coalesce((v_item ->> 'max_qty')::int, 50),
      true,
      coalesce((v_item ->> 'sort')::int, 0)
    )
    on conflict (sku) do update
      set label_km   = excluded.label_km,
          label_en   = excluded.label_en,
          -- Read the OLD cost before it is overwritten below: an unpriced SKU
          -- (price = old cost) follows the supplier; a staff price does not.
          price_usd  = case
                         when public.product_variants.price_usd = public.product_variants.cost_usd
                           then excluded.cost_usd
                         else public.product_variants.price_usd
                       end,
          cost_usd   = excluded.cost_usd,
          -- Quantity bounds follow the supplier's capability, so a re-sync
          -- repairs rows written before the cap existed.
          min_qty    = excluded.min_qty,
          max_qty    = excluded.max_qty,
          sort_order = excluded.sort_order,
          is_active  = true,
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

  -- ------------------------------------------------------------------------
  -- Reconcile: only when the pull actually returned products.
  -- ------------------------------------------------------------------------
  if jsonb_array_length(coalesce(p_products, '[]'::jsonb)) > 0 then
    -- Variants this supplier no longer lists for the game. Scoped to variants
    -- this supplier actually fulfils, so a staff-made or locally stocked line
    -- on the same product is never switched off by a sync.
    update public.product_variants v
       set is_active = false
     where v.product_id = v_product_id
       and v.is_active
       and exists (
         select 1 from public.supplier_skus s
          where s.variant_id = v.id and s.supplier_id = v_supplier.id
       )
       and v.sku not in (
         select (i ->> 'product_code') from jsonb_array_elements(p_products) i
       );

    get diagnostics v_deactivated = row_count;

    -- Their SKU links follow. An order already paid for a line whose SKU just
    -- disappeared becomes a staff problem rather than a silent retry loop: the
    -- supplier would reject the product_code anyway, so there is nothing left
    -- to attempt automatically.
    update public.supplier_skus s
       set is_active = false
     where s.supplier_id = v_supplier.id
       and s.is_active
       and not exists (
         select 1 from public.product_variants v
          where v.id = s.variant_id and v.is_active
       );

    -- A game with nothing on sale is hidden, not shown as an empty shelf.
    --
    -- Swept across this supplier's whole catalogue, not just the game being
    -- synced: a SKU can also leave a product by moving to another game, since
    -- the variant upsert reassigns product_id when the supplier reuses a
    -- product_code. That product is not named anywhere in this call.
    update public.products p
       set is_active = false,
           updated_at    = now()
     where p.supplier_id = v_supplier.id
       and p.is_active
       and not exists (
         select 1 from public.product_variants v
          where v.product_id = p.id and v.is_active
       );
  end if;

  return jsonb_build_object(
    'product_id', v_product_id,
    'slug', v_slug,
    'variants_synced', v_upserted,
    'variants_deactivated', v_deactivated
  );
end;
$$;

revoke execute on function public.supplier_upsert_catalogue(text, text, text, text, text, jsonb, jsonb)
  from public, anon, authenticated;
