-- ============================================================================
-- Buyer field patterns were enforced in the app only.
--
-- `create_order` checked that a required field was non-empty and nothing else,
-- while `product_page.dart` and `checkout_page.dart` each applied the
-- catalogue's own `pattern`. The app is a suggestion: the RPC is directly
-- reachable, and an older build of the app is a normal thing to be running.
--
-- What that cost: `userid = 'abc'` was accepted, the buyer paid, the supplier
-- rejected the id, and the automatic path refunded the wallet. The sale was
-- never going to happen, and the store paid a support ticket and a refund for
-- finding that out. Field definitions live on `products.requires_fields`:
--
--   [{"key":"userid","label_en":"Game ID","placeholder":"123456789",
--     "pattern":"^[0-9]{6,12}$"}]
--
-- So enforce the pattern where the order is created, alongside the check that
-- already lives there. Two rules, both narrow:
--   * the value must match the field's own `pattern`, when it has one;
--   * the value must be at most 64 characters, which no real id or server name
--     needs and which stops a megabyte of junk reaching a supplier's API.
--
-- The app keeps its copy of the check so the buyer is told before paying. This
-- is the one that counts.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- field_pattern_matches: match a value against a catalogue pattern, and treat
-- an unusable pattern as "no constraint".
--
-- A pattern is data, entered by staff or written by an adapter, so it can be
-- wrong. If it is, `~` raises and every order for that product fails — a whole
-- game becomes unsellable over a typo in a validation string. Failing open
-- here is the lesser evil, and it matches what the client does with an
-- uncompilable pattern. The catalogue's own sanitising happens on write.
-- ---------------------------------------------------------------------------
create or replace function public.field_pattern_matches(
  p_value   text,
  p_pattern text
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_value is null or coalesce(p_pattern, '') = '' then
    return true;
  end if;

  return p_value ~ p_pattern;
exception
  when others then
    return true;
end;
$$;

comment on function public.field_pattern_matches(text, text) is
  'Buyer field pattern test. An invalid pattern is treated as no pattern, so a '
  'bad validation string cannot make a product unsellable.';

revoke execute on function public.field_pattern_matches(text, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- create_order: same function, with the pattern and length rules added to the
-- existing non-empty check.
--
-- Re-created rather than amended, because the check lives inside it. The body
-- below is `20261015000300_rpc.sql` verbatim apart from the field gate and the
-- one extra local it needs.
-- ---------------------------------------------------------------------------
create or replace function public.create_order(
  p_items   jsonb,
  p_coupon  text default null,
  p_fields  jsonb default '{}'::jsonb,
  p_email   text default null,
  p_note    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user       uuid := (select auth.uid());
  v_profile    public.profiles;
  v_item       jsonb;
  v_variant    public.product_variants;
  v_product    public.products;
  v_qty        integer;
  v_stock      integer;
  v_subtotal   numeric(12, 2) := 0;
  v_discount   numeric(12, 2) := 0;
  v_total      numeric(12, 2);
  v_order_id   uuid;
  v_order_no   text;
  v_ttl        integer;
  v_required   jsonb;
  v_missing    text;
  v_invalid    text;
  v_has_stock  boolean := false;
begin
  if v_user is null then
    raise exception 'auth_required';
  end if;

  select * into v_profile from public.profiles where id = v_user;
  if v_profile.is_blocked then
    raise exception 'account_blocked';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'empty_cart';
  end if;

  if jsonb_array_length(p_items) > 20 then
    raise exception 'too_many_lines';
  end if;

  select order_ttl_minutes into v_ttl from public.settings where id;

  v_order_no := private.new_order_no();

  insert into public.orders (
    order_no, user_id, status, contact_email, customer_note, customer_fields, coupon_code, expires_at
  ) values (
    v_order_no, v_user, 'pending', p_email, p_note, coalesce(p_fields, '{}'::jsonb),
    nullif(btrim(coalesce(p_coupon, '')), ''),
    now() + make_interval(mins => v_ttl)
  ) returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_qty := greatest(coalesce((v_item ->> 'qty')::integer, 1), 1);

    select * into v_variant
      from public.product_variants
     where id = (v_item ->> 'variant_id')::bigint
       and is_active;

    if not found then
      raise exception 'variant_unavailable' using detail = (v_item ->> 'variant_id');
    end if;

    select * into v_product from public.products where id = v_variant.product_id and is_active;
    if not found then
      raise exception 'product_unavailable';
    end if;

    if v_qty < v_variant.min_qty or v_qty > v_variant.max_qty then
      raise exception 'qty_out_of_range' using detail = v_variant.sku;
    end if;

    -- Per-product buyer fields (game id, server, ...)
    if v_product.requires_fields is not null and jsonb_array_length(v_product.requires_fields) > 0 then
      select string_agg(f ->> 'key', ', ')
        into v_missing
        from jsonb_array_elements(v_product.requires_fields) f
       where coalesce(btrim(p_fields ->> (f ->> 'key')), '') = '';

      if v_missing is not null then
        raise exception 'missing_fields' using detail = v_missing;
      end if;

      -- Bounded, and in the shape the catalogue declares. Without this the
      -- supplier is the first thing to reject a bad id, which it does after
      -- the buyer has paid.
      select string_agg(f ->> 'key', ', ')
        into v_invalid
        from jsonb_array_elements(v_product.requires_fields) f
       where length(btrim(p_fields ->> (f ->> 'key'))) > 64
          or not public.field_pattern_matches(
               btrim(p_fields ->> (f ->> 'key')),
               f ->> 'pattern'
             );

      if v_invalid is not null then
        raise exception 'invalid_fields' using detail = v_invalid;
      end if;
    end if;

    if v_variant.stock_mode = 'stock' then
      select count(*) into v_stock
        from private.stock_items s
       where s.variant_id = v_variant.id and s.status = 'available';

      if v_stock < v_qty then
        raise exception 'out_of_stock' using detail = v_variant.sku;
      end if;
      v_has_stock := true;
    end if;

    v_subtotal := v_subtotal + (v_variant.price_usd * v_qty);

    insert into public.order_items (
      order_id, variant_id, product_name, variant_label,
      unit_price_usd, qty, line_total_usd, unit_cost_usd
    ) values (
      v_order_id, v_variant.id, v_product.name_km, v_variant.label_km,
      v_variant.price_usd, v_qty, v_variant.price_usd * v_qty, v_variant.cost_usd
    );
  end loop;

  v_discount := private.coupon_discount(p_coupon, v_user, v_subtotal);
  v_total := greatest(v_subtotal - v_discount, 0);

  update public.orders
     set subtotal_usd = v_subtotal,
         discount_usd = v_discount,
         total_usd    = v_total
   where id = v_order_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'subtotal_usd', v_subtotal,
    'discount_usd', v_discount,
    'total_usd', v_total,
    'expires_in_minutes', v_ttl
  );
end;
$$;
