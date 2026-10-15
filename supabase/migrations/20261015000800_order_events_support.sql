-- ============================================================================
-- Closes the schema gaps the specification names and the build did not have:
--
--   1. `order_events`  - an append-only status history. Every transition is
--      already made by a security definer RPC, so a trigger on `orders`
--      records them and no call site can forget to. Without it an order's
--      past is only inferable from timestamps.
--   2. `refund_pending` - the missing state. `failed -> refunded` used to be
--      the only path, which recorded a refund that a human had not yet made.
--      Money that has left the buyer's account needs a state that says
--      "agreed, not yet returned".
--   3. `support_tickets` - the "Contact support" action had nowhere to write.
--
-- Append-only is enforced by omission: no insert/update/delete grant reaches
-- `authenticated`, and the only writer is the trigger, which runs as definer.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. The missing order state
--
-- `add value if not exists` is idempotent, and the literal is only ever used
-- inside plpgsql bodies below, never in a top-level statement of this file, so
-- it is safe under a single-transaction apply (the SQL editor, `db push`).
-- ---------------------------------------------------------------------------
alter type public.order_status add value if not exists 'refund_pending';

-- Refund bookkeeping on the order itself.
alter table public.orders
  add column if not exists refund_reason text,
  add column if not exists refunded_at   timestamptz;

alter table public.payments
  add column if not exists refunded_at timestamptz;

-- ---------------------------------------------------------------------------
-- 2. order_events - append-only status history
-- ---------------------------------------------------------------------------
create table if not exists public.order_events (
  id          bigint generated always as identity primary key,
  order_id    uuid not null references public.orders (id) on delete cascade,
  -- Null on the 'created' row, which has no previous state.
  from_status public.order_status,
  to_status   public.order_status not null,
  -- Machine key for the UI: 'created', 'paid', 'delivering', 'delivered',
  -- 'failed', 'expired', 'refund_pending', 'refunded'.
  event       text not null,
  actor       text not null default 'system'
              check (actor in ('system', 'customer', 'staff', 'supplier')),
  actor_id    uuid,
  detail      jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists order_events_order_idx
  on public.order_events (order_id, created_at desc, id desc);

-- The only writer. A security definer trigger rather than calls inside each
-- RPC: `expire_stale_orders` and `supplier_complete_item` both move status,
-- and a call the next author forgets is a hole in the history.
create or replace function private.log_order_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_actor text := 'system';
begin
  -- deliver_order rewrites status to the same value on its second pass; the
  -- history should show the transition, not the no-op.
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return null;
  end if;

  if v_uid is not null then
    v_actor := case when public.is_staff() then 'staff' else 'customer' end;
  end if;

  insert into public.order_events (order_id, from_status, to_status, event, actor, actor_id)
  values (
    new.id,
    case when tg_op = 'UPDATE' then old.status else null end,
    new.status,
    case when tg_op = 'INSERT' then 'created' else new.status::text end,
    v_actor,
    v_uid
  );

  return null;
end;
$$;

drop trigger if exists orders_log_status on public.orders;
create trigger orders_log_status
  after insert or update of status on public.orders
  for each row execute function private.log_order_status();

-- ---------------------------------------------------------------------------
-- 3. support_tickets
-- ---------------------------------------------------------------------------
create table if not exists public.support_tickets (
  id          bigint generated always as identity primary key,
  user_id     uuid references public.profiles (id) on delete set null,
  order_id    uuid references public.orders (id) on delete set null,
  -- Kept separately: a buyer may want an answer at an address that is not the
  -- one they signed in with.
  contact     text,
  subject     text not null,
  body        text,
  status      text not null default 'open'
              check (status in ('open', 'in_progress', 'resolved', 'closed')),
  priority    text not null default 'normal'
              check (priority in ('low', 'normal', 'high')),
  admin_note  text,
  assigned_to uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists support_tickets_user_idx
  on public.support_tickets (user_id, created_at desc);
create index if not exists support_tickets_open_idx
  on public.support_tickets (status, created_at desc)
  where status in ('open', 'in_progress');

drop trigger if exists support_tickets_touch on public.support_tickets;
create trigger support_tickets_touch before update on public.support_tickets
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 4. RLS + grants
--
-- Supabase sets default privileges that expose new public tables, so the
-- revoke is load-bearing, not decoration. RLS is not inherited either.
-- ---------------------------------------------------------------------------
alter table public.order_events    enable row level security;
alter table public.support_tickets enable row level security;

revoke all on public.order_events, public.support_tickets from anon, authenticated;

grant select on public.order_events to authenticated;
grant select on public.support_tickets to authenticated;

-- No insert/update/delete policy and no grant: writes only through RPC.
drop policy if exists order_events_select_own on public.order_events;
create policy order_events_select_own on public.order_events
  for select to authenticated
  using (
    public.is_staff()
    or exists (
      select 1 from public.orders o
      where o.id = order_events.order_id and o.user_id = (select auth.uid())
    )
  );

drop policy if exists support_tickets_select_own on public.support_tickets;
create policy support_tickets_select_own on public.support_tickets
  for select to authenticated
  using (user_id = (select auth.uid()) or public.is_staff());

drop policy if exists support_tickets_staff_all on public.support_tickets;
create policy support_tickets_staff_all on public.support_tickets
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

-- ---------------------------------------------------------------------------
-- 5. Support RPCs
-- ---------------------------------------------------------------------------
create or replace function public.create_support_ticket(
  p_subject  text,
  p_body     text default null,
  p_order_id uuid default null,
  p_contact  text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_open integer;
  v_id   bigint;
begin
  if v_user is null then
    raise exception 'auth_required';
  end if;

  if coalesce(btrim(p_subject), '') = '' then
    raise exception 'subject_required';
  end if;

  -- The order may only be attached if it is the caller's own. A guessed UUID
  -- must not turn into a way to read someone else's order through the ticket.
  if p_order_id is not null and not exists (
    select 1 from public.orders o
    where o.id = p_order_id and o.user_id = v_user
  ) then
    raise exception 'order_not_found';
  end if;

  -- Abuse control: one ticket per 30 seconds, five open at a time.
  select count(*) into v_open
    from public.support_tickets
   where user_id = v_user and status in ('open', 'in_progress');

  if v_open >= 5 then
    raise exception 'too_many_open_tickets';
  end if;

  if exists (
    select 1 from public.support_tickets
    where user_id = v_user and created_at > now() - interval '30 seconds'
  ) then
    raise exception 'ticket_rate_limited';
  end if;

  insert into public.support_tickets (user_id, order_id, contact, subject, body)
  values (
    v_user,
    p_order_id,
    left(coalesce(p_contact, (select email from auth.users where id = v_user)), 200),
    left(btrim(p_subject), 200),
    left(p_body, 4000)
  )
  returning id into v_id;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values (v_user, 'support_ticket_created', 'support_ticket', v_id::text,
          jsonb_build_object('order_id', p_order_id));

  return jsonb_build_object('ok', true, 'ticket_id', v_id);
end;
$$;

grant execute on function public.create_support_ticket(text, text, uuid, text) to authenticated;

create or replace function public.admin_support_set_status(
  p_ticket_id bigint,
  p_status    text,
  p_note      text default null,
  p_priority  text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  update public.support_tickets
     set status      = coalesce(p_status, status),
         priority    = coalesce(p_priority, priority),
         admin_note  = coalesce(p_note, admin_note),
         assigned_to = (select auth.uid()),
         resolved_at = case when p_status in ('resolved', 'closed') then now() else null end
   where id = p_ticket_id;

  if not found then
    raise exception 'ticket_not_found';
  end if;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'support_ticket_status', 'support_ticket', p_ticket_id::text,
          jsonb_build_object('status', p_status));
end;
$$;

grant execute on function public.admin_support_set_status(bigint, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Refund RPCs
--
-- The two halves are deliberately separate. `refund_pending` says a refund was
-- agreed; `refunded` says the money actually went back. Collapsing them is how
-- a store reports a refund it never made.
--
-- Neither function moves money. Automatic refunds of a failed supplier line
-- already credit the buyer's wallet in `supplier_complete_item`; these record a
-- refund made outside that path (an ABA reversal), so crediting again here
-- would pay the buyer twice.
-- ---------------------------------------------------------------------------
create or replace function public.admin_order_set_refund_pending(
  p_order_id uuid,
  p_reason   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_order public.orders;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order_not_found';
  end if;

  -- 'pending' has captured no money to return, and the last two are terminal.
  if v_order.status not in ('paid', 'delivering', 'delivered', 'failed') then
    return jsonb_build_object('ok', false, 'status', v_order.status);
  end if;

  update public.orders
     set status = 'refund_pending',
         refund_reason = coalesce(p_reason, refund_reason)
   where id = p_order_id;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'order_refund_pending', 'order', p_order_id::text,
          jsonb_build_object('reason', p_reason, 'previous_status', v_order.status));

  return jsonb_build_object('ok', true, 'status', 'refund_pending');
end;
$$;

grant execute on function public.admin_order_set_refund_pending(uuid, text) to authenticated;

create or replace function public.admin_order_mark_refunded(
  p_order_id  uuid,
  p_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_order public.orders;
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'order_not_found';
  end if;

  -- Only from refund_pending: marking a live order refunded would abandon a
  -- delivery that may still be running.
  if v_order.status <> 'refund_pending' then
    return jsonb_build_object('ok', false, 'status', v_order.status);
  end if;

  update public.payments
     set status = 'refunded', refunded_at = now()
   where order_id = p_order_id and status = 'succeeded';

  update public.orders
     set status = 'refunded', refunded_at = now()
   where id = p_order_id;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'order_refunded', 'order', p_order_id::text,
          jsonb_build_object('reference', p_reference));

  return jsonb_build_object('ok', true, 'status', 'refunded');
end;
$$;

grant execute on function public.admin_order_mark_refunded(uuid, text) to authenticated;
