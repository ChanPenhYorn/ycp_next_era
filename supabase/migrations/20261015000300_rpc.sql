-- ============================================================================
-- Business logic. Everything the client can do goes through these functions;
-- tables stay read-only for customers. All money and stock maths is server-side.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Encryption helpers for the stock vault
-- ---------------------------------------------------------------------------
create or replace function private.stock_key()
returns text
language sql
stable
security definer
set search_path = ''
as $$ select value from private.secrets where name = 'stock_key'; $$;

create or replace function private.encrypt_payload(p_plain text)
returns bytea
language sql
stable
security definer
set search_path = ''
as $$
  select extensions.pgp_sym_encrypt(p_plain, private.stock_key(), 'cipher-algo=aes256');
$$;

create or replace function private.decrypt_payload(p_enc bytea)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select extensions.pgp_sym_decrypt(p_enc, private.stock_key());
$$;

-- ---------------------------------------------------------------------------
-- Order numbers
-- ---------------------------------------------------------------------------
create or replace function private.new_order_no()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare v text;
begin
  loop
    v := 'YP' || to_char(now() at time zone 'UTC', 'YYMMDD')
             || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (select 1 from public.orders o where o.order_no = v);
  end loop;
  return v;
end;
$$;

-- ---------------------------------------------------------------------------
-- Wallet ledger. Row-locks the profile so concurrent debits cannot oversell.
-- ---------------------------------------------------------------------------
create or replace function private.credit_wallet(
  p_user_id  uuid,
  p_amount   numeric,
  p_kind     public.wallet_kind,
  p_order_id uuid default null,
  p_note     text default null
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare v_balance numeric(12, 2);
begin
  update public.profiles
     set wallet_balance = wallet_balance + p_amount
   where id = p_user_id
  returning wallet_balance into v_balance;

  if not found then
    raise exception 'profile_not_found';
  end if;

  insert into public.wallet_transactions (user_id, kind, amount_usd, balance_after, order_id, note)
  values (p_user_id, p_kind, p_amount, v_balance, p_order_id, p_note);

  return v_balance;
end;
$$;

-- ---------------------------------------------------------------------------
-- Coupon validation (read-only preview + authoritative use inside create_order)
-- ---------------------------------------------------------------------------
create or replace function private.coupon_discount(
  p_code     text,
  p_user_id  uuid,
  p_subtotal numeric
)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare c public.coupons;
begin
  if p_code is null or btrim(p_code) = '' then
    return 0;
  end if;

  select * into c from public.coupons
   where upper(code) = upper(btrim(p_code))
     and is_active
     and starts_at <= now()
     and (expires_at is null or expires_at > now());

  if not found then
    raise exception 'coupon_invalid';
  end if;

  if c.max_uses is not null and c.used_count >= c.max_uses then
    raise exception 'coupon_exhausted';
  end if;

  if p_subtotal < c.min_order_usd then
    raise exception 'coupon_min_order' using detail = c.min_order_usd::text;
  end if;

  if p_user_id is not null and exists (
    select 1 from public.coupon_redemptions r
    where r.coupon_id = c.id and r.user_id = p_user_id
    group by r.coupon_id having count(*) >= c.per_user_limit
  ) then
    raise exception 'coupon_user_limit';
  end if;

  return case
    when c.kind = 'percent' then round(p_subtotal * c.value / 100, 2)
    else least(c.value, p_subtotal)
  end;
end;
$$;

create or replace function public.validate_coupon(p_code text, p_subtotal numeric)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_discount numeric;
begin
  v_discount := private.coupon_discount(p_code, (select auth.uid()), p_subtotal);
  return jsonb_build_object('ok', true, 'discount_usd', v_discount);
exception
  when others then
    return jsonb_build_object('ok', false, 'reason', sqlerrm);
end;
$$;

grant execute on function public.validate_coupon(text, numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- create_order: prices are always recomputed from the catalogue.
-- p_items: [{"variant_id": 1, "qty": 2}, ...]
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

grant execute on function public.create_order(jsonb, text, jsonb, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Delivery: atomic stock pickup, then per-kind handling
-- ---------------------------------------------------------------------------
create or replace function private.deliver_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item      record;
  v_picked    integer;
  v_pending   integer;
  v_waiting   integer;
  v_all_done  boolean;
begin
  update public.orders set status = 'delivering' where id = p_order_id and status = 'paid';

  for v_item in
    select oi.id, oi.variant_id, oi.qty, p.kind, oi.product_name
      from public.order_items oi
      join public.product_variants v on v.id = oi.variant_id
      join public.products p on p.id = v.product_id
     where oi.order_id = p_order_id
       and oi.delivery_status = 'pending'
     order by oi.id
  loop
    if v_item.kind = 'instant_stock' then
      -- The one statement that prevents double-selling.
      update private.stock_items s
         set status = 'sold', order_id = p_order_id, sold_at = now()
       where s.id in (
         select id
           from private.stock_items
          where variant_id = v_item.variant_id
            and status = 'available'
          order by created_at
          limit v_item.qty
          for update skip locked
       );

      get diagnostics v_picked = row_count;

      if v_picked = v_item.qty then
        update public.order_items
           set delivery_status = 'delivered', delivered_at = now()
         where id = v_item.id;

        update public.products
           set sold_count = sold_count + v_item.qty
         where id = (select product_id from public.product_variants where id = v_item.variant_id);
      else
        -- Roll back a short pick so nothing is stranded mid-order.
        if v_picked > 0 then
          update private.stock_items
             set status = 'available', order_id = null, sold_at = null
           where order_id = p_order_id
             and variant_id = v_item.variant_id
             and status = 'sold'
             and id in (select id from private.stock_items
                         where order_id = p_order_id and variant_id = v_item.variant_id
                         order by id desc limit v_picked);
        end if;

        update public.order_items
           set delivery_status = 'manual_waiting'
         where id = v_item.id;
      end if;

    elsif v_item.kind = 'manual_setup' then
      update public.order_items
         set delivery_status = 'manual_waiting'
       where id = v_item.id;

    else
      -- auto_topup: a worker calls the supplier API and flips this row.
      update public.order_items
         set delivery_status = 'pending'
       where id = v_item.id;
    end if;
  end loop;

  select
    count(*) filter (where delivery_status = 'pending'),
    count(*) filter (where delivery_status = 'manual_waiting')
    into v_pending, v_waiting
    from public.order_items where order_id = p_order_id;

  v_all_done := (v_pending = 0 and v_waiting = 0);

  update public.orders
     set status = case when v_all_done then 'delivered'::public.order_status else 'delivering'::public.order_status end,
         delivered_at = case when v_all_done then now() else delivered_at end
   where id = p_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- mark_order_paid: idempotent. Safe to call from a webhook more than once.
-- ---------------------------------------------------------------------------
create or replace function public.mark_order_paid(
  p_order_id     uuid,
  p_provider     public.payment_provider,
  p_provider_ref text default null,
  p_payway_method text default null,
  p_raw          jsonb default null,
  p_amount_khr   numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_order public.orders;
begin
  select * into v_order from public.orders where id = p_order_id for update;

  if not found then
    raise exception 'order_not_found';
  end if;

  if v_order.status not in ('pending', 'paid', 'delivering') then
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

    perform private.deliver_order(p_order_id);
  end if;

  return jsonb_build_object('ok', true, 'status', 'paid');
end;
$$;

-- Only the service role may settle an order.
revoke execute on function public.mark_order_paid(uuid, public.payment_provider, text, text, jsonb, numeric) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Pay from wallet (debit + settle in one transaction)
-- ---------------------------------------------------------------------------
create or replace function public.pay_order_with_wallet(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user  uuid := (select auth.uid());
  v_order public.orders;
  v_bal   numeric(12, 2);
begin
  if v_user is null then raise exception 'auth_required'; end if;

  select * into v_order from public.orders
   where id = p_order_id and user_id = v_user
   for update;

  if not found then raise exception 'order_not_found'; end if;
  if v_order.status <> 'pending' then
    return jsonb_build_object('ok', false, 'status', v_order.status);
  end if;
  if v_order.expires_at < now() then raise exception 'order_expired'; end if;

  select wallet_balance into v_bal from public.profiles where id = v_user for update;
  if v_bal < v_order.total_usd then
    return jsonb_build_object('ok', false, 'reason', 'insufficient_balance', 'balance', v_bal, 'required', v_order.total_usd);
  end if;

  perform private.credit_wallet(v_user, -v_order.total_usd, 'purchase', p_order_id, 'order ' || v_order.order_no);

  update public.orders set status = 'paid', paid_at = now() where id = p_order_id;

  insert into public.payments (order_id, provider, status, amount_usd, verified_at)
  values (p_order_id, 'wallet', 'succeeded', v_order.total_usd, now());

  perform private.deliver_order(p_order_id);

  return jsonb_build_object('ok', true, 'status', 'paid');
end;
$$;

grant execute on function public.pay_order_with_wallet(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- reveal_order: decrypted credentials for a paid order the caller owns
-- ---------------------------------------------------------------------------
create or replace function public.reveal_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null then raise exception 'auth_required'; end if;

  if not exists (
    select 1 from public.orders o
    where o.id = p_order_id
      and (o.user_id = v_user or public.is_staff())
      and o.status in ('paid', 'delivering', 'delivered')
  ) then
    raise exception 'not_authorized';
  end if;

  return (
    select coalesce(jsonb_agg(x order by x ->> 'item_id'), '[]'::jsonb)
    from (
      select jsonb_build_object(
        'item_id', oi.id,
        'product_name', oi.product_name,
        'variant_label', oi.variant_label,
        'qty', oi.qty,
        'delivery_status', oi.delivery_status,
        'payloads', (
          select coalesce(jsonb_agg(private.decrypt_payload(s.payload_enc) order by s.sold_at), '[]'::jsonb)
          from private.stock_items s
          where s.order_id = p_order_id and s.variant_id = oi.variant_id and s.status = 'sold'
        )
      ) as x
      from public.order_items oi
      where oi.order_id = p_order_id
    ) t
  );
end;
$$;

grant execute on function public.reveal_order(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Staff: add stock, resolve manual items, adjust wallet
-- ---------------------------------------------------------------------------
create or replace function public.admin_add_stock(p_variant_id bigint, p_payloads text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer := 0;
begin
  if not public.is_staff() then raise exception 'not_authorized'; end if;

  insert into private.stock_items (variant_id, payload_enc)
  select p_variant_id, private.encrypt_payload(p)
    from unnest(p_payloads) p
   where btrim(p) <> '';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.admin_add_stock(bigint, text[]) to authenticated;

create or replace function public.admin_resolve_item(
  p_item_id  bigint,
  p_delivery public.delivery_status default 'delivered'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_order uuid;
begin
  if not public.is_staff() then raise exception 'not_authorized'; end if;

  update public.order_items
     set delivery_status = p_delivery,
         delivered_at = case when p_delivery = 'delivered' then now() else null end
   where id = p_item_id
  returning order_id into v_order;

  if v_order is null then raise exception 'item_not_found'; end if;

  if not exists (
    select 1 from public.order_items
    where order_id = v_order and delivery_status <> 'delivered'
  ) then
    update public.orders
       set status = 'delivered', delivered_at = now()
     where id = v_order;
  end if;
end;
$$;

grant execute on function public.admin_resolve_item(bigint, public.delivery_status) to authenticated;

-- ---------------------------------------------------------------------------
-- Housekeeping: run on a schedule (pg_cron)
-- ---------------------------------------------------------------------------
create or replace function public.expire_stale_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  update private.stock_items
     set status = 'available', order_id = null, reserved_at = null
   where status = 'reserved'
     and reserved_at < now() - interval '30 minutes';

  with expired as (
    update public.orders
       set status = 'expired'
     where status = 'pending' and expires_at < now()
    returning id
  ),
  voided as (
    update public.payments p
       set status = 'expired'
      from expired e
     where p.order_id = e.id and p.status in ('initiated', 'pending')
    returning p.id
  )
  select count(*) into v_count from expired;

  return v_count;
end;
$$;

create or replace function public.refresh_product_ratings()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.products p
     set rating_avg = coalesce(r.avg_rating, 0),
         rating_count = coalesce(r.cnt, 0)
    from (
      select product_id, round(avg(rating)::numeric, 2) as avg_rating, count(*) as cnt
        from public.reviews
       where is_approved
       group by product_id
    ) r
   where p.id = r.product_id;
$$;
