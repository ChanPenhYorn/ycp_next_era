-- ============================================================================
-- The staff overview, as numbers that can be checked against a bank statement.
--
-- Everything a dashboard is tempted to invent — growth, "active users", a
-- conversion rate — is left out. What is here comes from two places only:
--
--   * `orders` counts, by status. A row is a row.
--   * `payments` sums, split by where the money came from.
--
-- The split matters. A wallet-funded purchase creates a `payments` row with
-- provider 'wallet' and no money arrives; the cash arrived earlier, when the
-- balance was topped up. Summing `orders.total_usd` therefore counts one
-- barrel of money twice, once as the top-up and again as the purchase it paid
-- for. So:
--
--   received_*   money that reached the bank (payway / khqr_direct / manual)
--   wallet_spent_* orders settled from a balance — not new money
--   refunded_*   reported separately and never netted off
--
-- A refunded payment still counts as received: it did arrive. Netting it out of
-- the window it arrived in would silently rewrite history, and the pair of
-- figures reads as gross and returns, which is what a bookkeeper can reconcile.
--
-- One more thing that is easy to get wrong: `now()` is UTC and the store is in
-- Phnom Penh, so "today" is a seven-hours-elsewhere boundary. It is computed in
-- the store's timezone here, and the timezone is returned with the numbers so
-- the screen can say which day it means.
-- ============================================================================

create or replace function public.admin_overview()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tz        text := 'Asia/Phnom_Penh';
  v_day_start timestamptz;
  v_7d        timestamptz;
  v_30d       timestamptz;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  v_day_start := date_trunc('day', now() at time zone v_tz) at time zone v_tz;
  v_7d        := now() - interval '7 days';
  v_30d       := now() - interval '30 days';

  return jsonb_build_object(
    'timezone', v_tz,
    'generated_at', now(),

    -- Work waiting for a person, each one a queue that exists elsewhere in the
    -- app. They are here so the overview answers "what needs doing".
    'orders_pending', (select count(*) from public.orders o
                        where o.status = 'pending'),
    'orders_refund_pending', (select count(*) from public.orders o
                               where o.status = 'refund_pending'),
    'transfers_waiting', (select count(*) from public.orders o
                           where o.manual_payment_requested_at is not null
                             and o.status = 'pending'),
    'support_open', (select count(*) from public.support_tickets t
                      where t.status in ('open', 'in_progress')),
    'items_manual_waiting', (select count(*) from public.order_items i
                              where i.delivery_status = 'manual_waiting'),

    -- Money into the bank.
    'received_today', (select count(*) from public.payments p
                        where p.provider in ('payway', 'khqr_direct', 'manual')
                          and p.status in ('succeeded', 'refunded')
                          and p.verified_at >= v_day_start),
    'received_today_usd', (select coalesce(sum(p.amount_usd), 0) from public.payments p
                            where p.provider in ('payway', 'khqr_direct', 'manual')
                              and p.status in ('succeeded', 'refunded')
                              and p.verified_at >= v_day_start),
    'received_7d_usd', (select coalesce(sum(p.amount_usd), 0) from public.payments p
                         where p.provider in ('payway', 'khqr_direct', 'manual')
                           and p.status in ('succeeded', 'refunded')
                           and p.verified_at >= v_7d),
    'received_30d_usd', (select coalesce(sum(p.amount_usd), 0) from public.payments p
                          where p.provider in ('payway', 'khqr_direct', 'manual')
                            and p.status in ('succeeded', 'refunded')
                            and p.verified_at >= v_30d),

    -- Balance spent, which is not new money.
    'wallet_spent_30d_usd', (select coalesce(sum(p.amount_usd), 0) from public.payments p
                              where p.provider = 'wallet'
                                and p.status = 'succeeded'
                                and p.verified_at >= v_30d),

    -- Money paid back out.
    'refunds_30d', (select count(*) from public.orders o
                     where o.refunded_at >= v_30d),
    'refunded_30d_usd', (select coalesce(sum(o.total_usd), 0) from public.orders o
                          where o.refunded_at >= v_30d)
  );
end;
$$;

grant execute on function public.admin_overview() to authenticated;
