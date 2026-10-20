-- ============================================================================
-- An auto top-up that no supplier can deliver is a staff job, not a pending one.
--
-- `private.deliver_order` marks every `auto_topup` line `pending` and leaves it
-- for the supplier worker. That is right when a supplier is linked. It is wrong
-- when the variant has no active supplier SKU at all:
--
--   * `supplier_pending_items` returns it with a null `supplier_sku`, so the
--     worker can only defer it and never deliver it;
--   * the line never records an attempt, and `admin_supplier_queue` lists only
--     lines that are `manual_waiting` or have `supplier_attempts > 0`;
--
-- so the order sits in `delivering` for ever, invisible to the only person who
-- could finish it. The demo catalogue hits this: `mobile-legends-diamonds` is
-- `auto_topup` with no supplier link, and every purchase of it parks there.
--
-- Two pieces:
--
--   private.deliver_order                  auto_topup: linked -> pending
--                                                      unlinked -> manual_waiting
--   public.supplier_backfill_unlinked_items()   the same repair for lines that
--                                          are already stuck, run once here
--
-- An unlinked line is not an error state. It means "a person delivers this",
-- which is exactly what `manual_waiting` says everywhere else in the schema.
-- ============================================================================

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
    select oi.id, oi.variant_id, oi.qty, p.kind, oi.product_name,
           -- Whether a worker could ever finish this line: it needs an active
           -- supplier SKU to order. The supplier row's own `is_active` is
           -- deliberately not part of this: it is a switch staff flip, sometimes
           -- off for a day, and `supplier_pending_items` still hands those lines
           -- to the worker on purpose, which defers them and escalates to staff
           -- after the attempt limit. What can never be delivered, and so must
           -- not pretend to wait for a worker, is a line with no SKU behind it.
           exists (
             select 1
               from public.supplier_skus ss
              where ss.variant_id = v.id
                and ss.is_active
           ) as has_supplier
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

    elsif v_item.has_supplier then
      -- auto_topup with a supplier: a worker calls their API and flips this row.
      update public.order_items
         set delivery_status = 'pending'
       where id = v_item.id;

    else
      -- auto_topup with nothing to call: staff deliver it by hand.
      update public.order_items
         set delivery_status = 'manual_waiting'
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
-- The repair for lines delivered before the rule above existed.
--
-- Orders already sitting in `delivering` on an unlinked auto top-up line are
-- the exact case this migration is about, and nothing would move them: the
-- worker cannot claim them and staff cannot see them. This flips them to
-- `manual_waiting`, where `admin_supplier_queue` picks them up.
--
-- Only orders that are actually waiting on delivery are touched. A `pending`
-- line on an expired order is not stuck, it is simply an order that was never
-- paid, and dragging those into the staff queue would bury the real work.
--
-- Kept as a function rather than a bare `update` so it is re-runnable: a later
-- migration, or a supplier being unlinked by hand, can leave the same debris.
-- ---------------------------------------------------------------------------
create or replace function public.supplier_backfill_unlinked_items()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_moved integer;
begin
  update public.order_items oi
     set delivery_status = 'manual_waiting'
    from public.product_variants v
    join public.products p on p.id = v.product_id
   where v.id = oi.variant_id
     and oi.delivery_status = 'pending'
     and p.kind = 'auto_topup'
     and exists (
       select 1 from public.orders o
        where o.id = oi.order_id
          and o.status in ('paid', 'delivering')
     )
     and not exists (
       select 1
         from public.supplier_skus ss
        where ss.variant_id = v.id
          and ss.is_active
     );

  get diagnostics v_moved = row_count;

  -- The order's own status does not change: it is still 'delivering', because
  -- the goods are still owed. Only the person responsible changes.
  return v_moved;
end;
$$;

-- Operator/support function, like the other `admin_*` repairs: definer, so it
-- can read the private tables, and reachable from the SQL editor rather than
-- from a client.
revoke execute on function public.supplier_backfill_unlinked_items() from public, anon, authenticated;

do $$
declare v_moved integer;
begin
  select public.supplier_backfill_unlinked_items() into v_moved;
  raise notice 'supplier_manual_fallback: % stuck auto top-up line(s) handed to staff', v_moved;
end $$;
