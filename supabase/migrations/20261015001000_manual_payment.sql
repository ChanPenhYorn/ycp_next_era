-- ============================================================================
-- Manual KHQR fallback: a transfer a human confirms.
--
-- The automated path is PayWay: `payway-init` returns a per-order KHQR,
-- `payway-verify` polls, and the settlement lands in `mark_order_paid`. That is
-- the path to prefer, and this does not replace it. What it covers is the case
-- where it cannot run at all — no PayWay credential on the project, or a buyer
-- whose bank app will not open the deeplink — and the alternative today is that
-- the order cannot be paid for.
--
-- Three rules, and the shape of all three is deliberate:
--
--   1. There is still ONE settlement path. `mark_order_paid` is called with
--      provider 'manual' (the enum value already existed, unused). Stock
--      allocation, coupon redemption, the wallet top-up branch and the supplier
--      queue therefore behave exactly as they do after a PayWay settlement.
--      A second implementation is how the two drift apart and money moves twice.
--
--   2. The amount is stated, not assumed. PayWay has no choice but to ask ABA
--      what was paid (`_shared/settle.ts` compares that against the order total
--      and refuses to deliver on a shortfall). A human has to do the same: the
--      staff member enters what landed, and the RPC refuses anything below the
--      total. "The buyer said they paid" is not an amount.
--
--   3. A screenshot is never evidence and a transfer reference is never reused.
--      `payments` is unique on (provider, provider_ref). Confirming a second
--      order with a reference already on a first one would silently re-point the
--      existing row while still settling the second order — one transfer paid
--      for two orders. The RPC refuses that outright.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Order state, and how long a buyer gets after asking to pay by transfer
-- ---------------------------------------------------------------------------
alter table public.orders
  add column if not exists manual_payment_requested_at timestamptz,
  add column if not exists manual_payment_note         text;

comment on column public.orders.manual_payment_requested_at is
  'Set when the buyer asks to pay by transfer instead of KHQR. Cleared when '
  'staff confirm or dismiss it.';

alter table public.settings
  add column if not exists manual_grace_minutes integer not null default 1440;

comment on column public.settings.manual_grace_minutes is
  'How long an order stays payable after the buyer asks to pay by transfer. '
  'An instant transfer is not instant: the default 15-minute TTL expires the '
  'order before the money arrives, and staff would then be confirming an order '
  'that housekeeping has already cancelled.';

-- The app reads the view, not the table.
create or replace view public.public_settings as
select
  id, site_name, support_telegram, support_email, usd_to_khr, order_ttl_minutes,
  khqr_account_id, khqr_merchant_name, khqr_merchant_city, is_maintenance,
  topup_min_usd, topup_max_usd, telegram_bot_username, manual_grace_minutes
from public.settings;

grant select on public.public_settings to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. The buyer asks
--
-- No money moves here. This books a request and keeps the order payable long
-- enough for the transfer to land.
-- ---------------------------------------------------------------------------
create or replace function public.request_manual_payment(
  p_order_id uuid,
  p_note     text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user   uuid := (select auth.uid());
  v_order  public.orders;
  v_grace  integer;
  v_recent integer;
begin
  if v_user is null then
    raise exception 'auth_required';
  end if;

  select * into v_order
    from public.orders
   where id = p_order_id and user_id = v_user
   for update;

  -- Own order only, and the same error either way so a guessed UUID cannot be
  -- used to find out whether an order exists.
  if not found then
    raise exception 'order_not_found';
  end if;

  if v_order.status <> 'pending' then
    raise exception 'order_not_pending' using detail = v_order.status::text;
  end if;

  -- Asking twice keeps the first request: a repeat must not push the expiry out
  -- again, or the flag becomes a way to hold a price indefinitely.
  if v_order.manual_payment_requested_at is not null then
    return jsonb_build_object(
      'ok', true,
      'already_requested', true,
      'requested_at', v_order.manual_payment_requested_at,
      'expires_at', v_order.expires_at
    );
  end if;

  -- Abuse control: three requests an hour, counting the ones already made.
  select count(*) into v_recent
    from public.orders
   where user_id = v_user
     and manual_payment_requested_at > now() - interval '1 hour';

  if v_recent >= 3 then
    raise exception 'manual_rate_limited';
  end if;

  select coalesce(nullif(manual_grace_minutes, 0), 1440)
    into v_grace
    from public.settings where id;

  update public.orders
     set manual_payment_requested_at = now(),
         manual_payment_note = left(nullif(btrim(coalesce(p_note, '')), ''), 300),
         -- Never shortens an order that already had longer to run.
         expires_at = greatest(expires_at, now() + make_interval(mins => v_grace))
   where id = p_order_id
  returning * into v_order;

  -- No status change, so the trigger stays quiet and this is written here. The
  -- history is meant to show that the buyer asked, not only what the status did.
  insert into public.order_events (
    order_id, from_status, to_status, event, actor, actor_id, detail
  ) values (
    p_order_id, 'pending', 'pending', 'manual_payment_requested', 'customer', v_user,
    jsonb_strip_nulls(jsonb_build_object(
      'note', v_order.manual_payment_note,
      'expires_at', v_order.expires_at,
      'grace_minutes', v_grace
    ))
  );

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values (v_user, 'manual_payment_requested', 'order', p_order_id::text,
          jsonb_build_object('order_no', v_order.order_no, 'grace_minutes', v_grace));

  return jsonb_build_object(
    'ok', true,
    'already_requested', false,
    'requested_at', v_order.manual_payment_requested_at,
    'expires_at', v_order.expires_at
  );
end;
$$;

grant execute on function public.request_manual_payment(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Staff confirm what actually arrived
--
-- Staff-only, and it delegates the settlement itself: the same
-- `mark_order_paid` the PayWay path calls, so nothing new moves money.
-- ---------------------------------------------------------------------------
create or replace function public.admin_confirm_manual_payment(
  p_order_id   uuid,
  p_amount_usd numeric,
  p_aba_ref    text,
  p_note       text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order     public.orders;
  v_ref       text := btrim(coalesce(p_aba_ref, ''));
  v_other     text;
  v_result    jsonb;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  if p_amount_usd is null or p_amount_usd <= 0 then
    raise exception 'amount_required';
  end if;

  -- The reference is the only thing standing between one transfer and two
  -- orders, so it is required rather than optional.
  if v_ref = '' then
    raise exception 'manual_reference_required';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order_not_found';
  end if;

  -- Already settled: report it rather than raising, so the screen can say so
  -- instead of showing an error for a double click.
  if v_order.status <> 'pending' then
    return jsonb_build_object('ok', false, 'status', v_order.status);
  end if;

  -- An expired order is not settled here. The money is real, so it goes down the
  -- external-refund path (admin_order_set_refund_pending -> admin_order_mark_refunded)
  -- where a human handles it, rather than being quietly accepted into an order
  -- that housekeeping has already cancelled.
  if v_order.expires_at <= now() then
    raise exception 'order_expired';
  end if;

  -- What landed must cover the total. Same rule the automated path applies.
  if p_amount_usd + 0.0001 < v_order.total_usd then
    raise exception 'manual_underpaid' using detail = v_order.total_usd::text;
  end if;

  -- One transfer, one order.
  select o.order_no into v_other
    from public.payments p
    join public.orders o on o.id = p.order_id
   where p.provider = 'manual'
     and p.provider_ref = v_ref
     and p.order_id <> p_order_id
   limit 1;

  if v_other is not null then
    raise exception 'manual_reference_used' using detail = v_other;
  end if;

  -- Written before the settlement so the history reads in the order things
  -- happened. Both statements are in this transaction, so a failure in the
  -- settlement takes the entry with it.
  insert into public.order_events (
    order_id, from_status, to_status, event, actor, actor_id, detail
  ) values (
    p_order_id, 'pending', 'paid', 'manual_payment_confirmed', 'staff',
    (select auth.uid()),
    jsonb_build_object(
      'aba_ref', v_ref,
      'declared_amount_usd', p_amount_usd,
      'total_usd', v_order.total_usd
    )
  );

  v_result := public.mark_order_paid(
    p_order_id,
    'manual',
    v_ref,
    null,
    jsonb_strip_nulls(jsonb_build_object(
      'verified_by', (select auth.uid()),
      'declared_amount_usd', p_amount_usd,
      'note', nullif(btrim(coalesce(p_note, '')), '')
    )),
    null
  );

  -- Settled, so it leaves the queue. The request itself stays in the order
  -- history, where it belongs.
  update public.orders
     set manual_payment_requested_at = null,
         manual_payment_note = null
   where id = p_order_id;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'manual_payment_confirmed', 'order', p_order_id::text,
          jsonb_build_object(
            'order_no', v_order.order_no,
            'aba_ref', v_ref,
            'declared_amount_usd', p_amount_usd
          ));

  return v_result || jsonb_build_object('provider', 'manual', 'aba_ref', v_ref);
end;
$$;

grant execute on function public.admin_confirm_manual_payment(uuid, numeric, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Staff dismiss a request that will not be paid
--
-- Without this the queue only grows. No money moves and nothing is refunded:
-- the order simply goes back to being an unpaid order that can expire.
-- ---------------------------------------------------------------------------
create or replace function public.admin_clear_manual_payment_request(
  p_order_id uuid,
  p_reason   text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'reason_required';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order_not_found';
  end if;

  update public.orders
     set manual_payment_requested_at = null,
         manual_payment_note = null
   where id = p_order_id;

  insert into public.order_events (
    order_id, from_status, to_status, event, actor, actor_id, detail
  ) values (
    p_order_id, v_order.status, v_order.status, 'manual_payment_cleared', 'staff',
    (select auth.uid()), jsonb_build_object('reason', left(btrim(p_reason), 300))
  );

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'manual_payment_cleared', 'order', p_order_id::text,
          jsonb_build_object('order_no', v_order.order_no, 'reason', left(btrim(p_reason), 300)));

  return jsonb_build_object('ok', true, 'status', v_order.status);
end;
$$;

grant execute on function public.admin_clear_manual_payment_request(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. The staff queue, as a view
--
-- `security_invoker` is not decoration. A plain view belongs to its owner and
-- reads the base table as that owner, which would hand every customer in the
-- table to any signed-in caller. With security_invoker the policies on `orders`
-- apply to whoever queries it, so a staff session gets the queue and a customer
-- session gets nothing.
-- ---------------------------------------------------------------------------
create or replace view public.staff_manual_payments
with (security_invoker = true) as
select
  o.id            as order_id,
  o.order_no,
  o.status,
  o.total_usd,
  o.kind,
  o.manual_payment_requested_at as requested_at,
  o.manual_payment_note         as buyer_note,
  o.expires_at,
  o.created_at,
  o.customer_fields,
  o.contact_email
from public.orders o
where o.manual_payment_requested_at is not null
  and o.status = 'pending'
order by o.manual_payment_requested_at;

comment on view public.staff_manual_payments is
  'Orders where the buyer has asked to pay by transfer. Empty the queue with '
  'admin_confirm_manual_payment or admin_clear_manual_payment_request.';

grant select on public.staff_manual_payments to authenticated;
