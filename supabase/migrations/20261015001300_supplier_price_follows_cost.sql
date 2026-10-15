-- ============================================================================
-- A synced SKU that nobody has repriced kept its first sync's price forever.
--
-- `supplier_upsert_catalogue` updated `cost_usd` on a re-sync but never
-- `price_usd`. That is right for a retail price staff set by hand, which must
-- survive a sync. It is wrong for an unpriced SKU: its price IS its cost, so
-- when the supplier moved the cost, the storefront kept selling at the old one.
--
-- Fix: on re-sync, move `price_usd` to the new cost only while it still equals
-- the previous cost. Anything staff changed is left alone.
--
-- Only the variant upsert changes. The function is re-created in full because
-- plpgsql bodies cannot be patched. The grant from 700 survives `create or
-- replace`.
-- ============================================================================

create or replace function public.supplier_upsert_catalogue(
  p_supplier_code text,
  p_game_code     text,
  p_name          text,
  p_image_url     text,
  p_summary       text,
  p_required_fields jsonb,      -- ["userid","serverid"] or [{ key, label_km, label_en }]
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
  v_fields jsonb;
  v_upserted integer := 0;
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
        updated_at    = now()
  returning id into v_product_id;

  for v_item in select * from jsonb_array_elements(p_products)
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
      'unlimited', 1, 50, true, coalesce((v_item ->> 'sort')::int, 0)
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

  return jsonb_build_object(
    'product_id', v_product_id,
    'slug', v_slug,
    'variants_synced', v_upserted
  );
end;
$$;
