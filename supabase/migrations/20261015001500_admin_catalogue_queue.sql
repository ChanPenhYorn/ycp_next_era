-- ============================================================================
-- Staff controls for the catalogue and the supplier queue.
--
-- Products and variants have no write grants for `authenticated`, by design:
-- every write goes through a definer RPC that re-checks `is_staff()`. Until now
-- staff could only change a product with raw SQL.
--
--   admin_product_set_active   show or hide a product
--   admin_variant_set_price    set a retail price; refused below cost
--   admin_supplier_queue       lines the supplier worker could not finish
-- ============================================================================

create or replace function public.admin_product_set_active(
  p_product_id bigint,
  p_active     boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_slug text;
begin
  if not public.is_staff() then raise exception 'not_authorized'; end if;
  if p_active is null then raise exception 'invalid_active'; end if;

  update public.products
     set is_active = p_active
   where id = p_product_id
  returning slug into v_slug;

  if not found then raise exception 'product_not_found'; end if;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'product_set_active', 'product', p_product_id::text,
          jsonb_build_object('slug', v_slug, 'is_active', p_active));

  return jsonb_build_object('ok', true, 'id', p_product_id, 'is_active', p_active);
end;
$$;

grant execute on function public.admin_product_set_active(bigint, boolean) to authenticated;

create or replace function public.admin_variant_set_price(
  p_variant_id bigint,
  p_price_usd  numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cost numeric;
  v_old  numeric;
begin
  if not public.is_staff() then raise exception 'not_authorized'; end if;
  if p_price_usd is null or p_price_usd <= 0 then raise exception 'invalid_price'; end if;

  select cost_usd, price_usd into v_cost, v_old
    from public.product_variants
   where id = p_variant_id
     for update;

  if not found then raise exception 'variant_not_found'; end if;

  -- A sale below what the supplier charges loses money on every order. Refuse
  -- it here, not only in the app.
  if v_cost is not null and round(p_price_usd, 2) < v_cost then
    raise exception 'price_below_cost' using detail = v_cost::text;
  end if;

  update public.product_variants
     set price_usd = round(p_price_usd, 2)
   where id = p_variant_id;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'variant_set_price', 'product_variant', p_variant_id::text,
          jsonb_build_object('old_price_usd', v_old, 'new_price_usd', round(p_price_usd, 2),
                             'cost_usd', v_cost));

  return jsonb_build_object('ok', true, 'id', p_variant_id,
                            'price_usd', round(p_price_usd, 2));
end;
$$;

grant execute on function public.admin_variant_set_price(bigint, numeric) to authenticated;

-- Two states, because they need different action. `retrying` is the worker
-- backing off (the line will try again on its own). `manual_waiting` has used
-- its attempts and needs a person.
create or replace function public.admin_supplier_queue(p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_staff() then raise exception 'not_authorized'; end if;

  return coalesce((
    select jsonb_agg(row_to_json(q) order by q.state, q.item_id)
      from (
        select oi.id as item_id,
               o.id as order_id,
               o.order_no,
               oi.product_name,
               oi.variant_label,
               oi.qty,
               s.code as supplier_code,
               oi.delivery_status,
               case when oi.delivery_status = 'manual_waiting' then 'manual_waiting'
                    else 'retrying' end as state,
               oi.supplier_attempts,
               oi.supplier_last_error,
               oi.supplier_next_attempt_at,
               o.created_at
          from public.order_items oi
          join public.orders o on o.id = oi.order_id
          left join public.product_variants v on v.id = oi.variant_id
          left join public.products p on p.id = v.product_id
          left join public.suppliers s on s.id = p.supplier_id
         where oi.delivery_status in ('pending', 'manual_waiting')
           and (oi.delivery_status = 'manual_waiting' or oi.supplier_attempts > 0)
         order by oi.id
         limit least(greatest(coalesce(p_limit, 50), 1), 200)
      ) q
  ), '[]'::jsonb);
end;
$$;

grant execute on function public.admin_supplier_queue(integer) to authenticated;
