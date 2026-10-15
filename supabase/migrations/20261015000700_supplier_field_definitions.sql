-- ============================================================================
-- Supplier buyer fields must be field DEFINITIONS, not bare names.
--
-- `20261015000600_suppliers.sql` stored a game's `game_fields` verbatim, so a
-- Bay2Game product ended up with:
--
--   requires_fields = ["userid","serverid"]
--
-- Every other part of the system expects the object shape the seeds use:
--
--   [{"key":"userid","label_km":"...","label_en":"Game ID",...}]
--
--   - the app reads `key`, `label_km`, `label_en` off each entry
--     (`RequiredField.fromJson`), and `catalog_repository.dart` casts each one
--     to a Map, so a bare string threw and the whole product page failed.
--   - `create_order` resolves the missing-field list with `f ->> 'key'`, which
--     is NULL for a string entry, so `string_agg` returned NULL and the check
--     was skipped entirely. The order went through with no game id, the buyer
--     paid, and the adapter then refunded `missing_game_user_id`.
--
-- Normalise on write, tolerate both shapes on input, and repair rows already
-- synced by the old code.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- supplier_field_definitions: coerce a game's field list into definitions.
--
-- Accepts ["userid", ...] and [{"key":"userid", ...}, ...] so an adapter that
-- carries no label metadata still produces a renderable field, and so the
-- previous shape keeps working. Missing labels fall back to the key. Entries
-- with no resolvable key are dropped rather than stored unusable.
-- ---------------------------------------------------------------------------
create or replace function public.supplier_field_definitions(p_fields jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(entry order by ord), '[]'::jsonb)
  from (
    select
      case
        when jsonb_typeof(f.elem) = 'string' then
          jsonb_build_object(
            'key', f.elem #>> '{}',
            'label_km', f.elem #>> '{}',
            'label_en', f.elem #>> '{}'
          )
        else
          -- Strip nulls first so a null placeholder is absent, not present-null.
          jsonb_strip_nulls(f.elem)
            || jsonb_build_object(
                 'label_km', coalesce(nullif(f.elem ->> 'label_km', ''), f.elem ->> 'key'),
                 'label_en', coalesce(nullif(f.elem ->> 'label_en', ''), f.elem ->> 'key')
               )
      end as entry,
      f.ord
    from jsonb_array_elements(
      case when jsonb_typeof(p_fields) = 'array' then p_fields else '[]'::jsonb end
    ) with ordinality as f(elem, ord)
    where coalesce(
            case
              when jsonb_typeof(f.elem) = 'string' then f.elem #>> '{}'
              else f.elem ->> 'key'
            end, ''
          ) <> ''
  ) s;
$$;

revoke execute on function public.supplier_field_definitions(jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Repair products the old sync already wrote with bare field names.
-- ---------------------------------------------------------------------------
update public.products
   set requires_fields = public.supplier_field_definitions(requires_fields),
       updated_at = now()
 where jsonb_typeof(requires_fields) = 'array'
   and exists (
     select 1 from jsonb_array_elements(requires_fields) f
      where jsonb_typeof(f) = 'string'
   );

-- ---------------------------------------------------------------------------
-- supplier_upsert_catalogue: same contract, normalised fields.
-- ---------------------------------------------------------------------------
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
    -- Name the failure. A product payload whose key does not match
    -- `product_code` used to surface as a product_variants.sku not-null
    -- violation, which says nothing about the caller being wrong.
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
          cost_usd   = excluded.cost_usd,
          -- The supplier's list order is the display order. Leaving this out
          -- froze the first sync's ordering forever, so a re-sync could never
          -- correct a pack that moved.
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

revoke execute on function public.supplier_upsert_catalogue(text, text, text, text, text, jsonb, jsonb)
  from public, anon, authenticated;
