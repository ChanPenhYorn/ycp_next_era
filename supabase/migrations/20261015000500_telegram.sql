-- ============================================================================
-- Telegram: account linking, and an outbox so notifications are durable.
--
-- Why an outbox rather than sending directly: an instant order is delivered
-- inside mark_order_paid, but a manual or supplier order is delivered minutes
-- or hours later by a different actor. Writing the message to a table means the
-- notification cannot be lost if the sender is not around at that moment.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Settings the bot needs
-- ---------------------------------------------------------------------------
alter table public.settings
  add column if not exists telegram_bot_username text,
  add column if not exists support_telegram_chat_id bigint;

create or replace view public.public_settings as
select
  id, site_name, support_telegram, support_email, usd_to_khr, order_ttl_minutes,
  khqr_account_id, khqr_merchant_name, khqr_merchant_city, is_maintenance,
  topup_min_usd, topup_max_usd, telegram_bot_username
from public.settings;

grant select on public.public_settings to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Linking
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists telegram_chat_id bigint,
  add column if not exists telegram_username text,
  add column if not exists telegram_linked_at timestamptz;

create unique index if not exists profiles_telegram_chat_idx
  on public.profiles (telegram_chat_id) where telegram_chat_id is not null;

create table if not exists public.telegram_link_codes (
  code       text primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '15 minutes'),
  used_at    timestamptz,
  created_at timestamptz not null default now()
);

alter table public.telegram_link_codes enable row level security;
-- No policies and no grants: reached only through the functions below.

-- ---------------------------------------------------------------------------
-- Outbox
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id         bigint generated always as identity primary key,
  user_id    uuid references public.profiles (id) on delete cascade,
  chat_id    bigint,
  kind       text not null,
  payload    jsonb not null default '{}'::jsonb,
  status     text not null default 'pending'
             check (status in ('pending', 'sending', 'sent', 'failed', 'skipped')),
  attempts   integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  sent_at    timestamptz
);

alter table public.notifications enable row level security;

create index if not exists notifications_pending_idx
  on public.notifications (created_at) where status = 'pending';

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Enqueue on terminal order states.
--
-- Deliberately only 'delivered' and 'failed': notifying on 'paid' would fire a
-- second message milliseconds later for instant orders, and 'delivering' means
-- nothing to the buyer yet.
-- ---------------------------------------------------------------------------
create or replace function private.enqueue_order_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_chat bigint;
begin
  if new.status = old.status then
    return new;
  end if;

  if new.status not in ('delivered', 'failed') then
    return new;
  end if;

  select p.telegram_chat_id into v_chat
    from public.profiles p where p.id = new.user_id;

  insert into public.notifications (user_id, chat_id, kind, payload)
  values (
    new.user_id,
    v_chat,
    case new.status
      when 'delivered' then 'order_delivered'
      else 'order_failed'
    end,
    jsonb_build_object(
      'order_id', new.id,
      'order_no', new.order_no,
      'total_usd', new.total_usd,
      'kind', new.kind
    )
  );

  return new;
end;
$$;

drop trigger if exists orders_notify on public.orders;
create trigger orders_notify
  after update on public.orders
  for each row execute function private.enqueue_order_notification();

-- ---------------------------------------------------------------------------
-- create_telegram_link_code: the app shows a code, the buyer sends it to the bot
-- ---------------------------------------------------------------------------
create or replace function public.create_telegram_link_code()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user   uuid := (select auth.uid());
  v_code   text;
  v_bot    text;
begin
  if v_user is null then
    raise exception 'auth_required';
  end if;

  -- One live code per user.
  delete from public.telegram_link_codes
   where user_id = v_user and used_at is null;

  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.telegram_link_codes (code, user_id) values (v_code, v_user);

  select telegram_bot_username into v_bot from public.settings where id;

  return jsonb_build_object(
    'code', v_code,
    'expires_in_minutes', 15,
    'bot_username', v_bot,
    'deep_link', case
      when v_bot is null then null
      else 'https://t.me/' || v_bot || '?start=' || v_code
    end
  );
end;
$$;

grant execute on function public.create_telegram_link_code() to authenticated;

-- ---------------------------------------------------------------------------
-- link_telegram: called by the webhook after /start <code>
-- ---------------------------------------------------------------------------
create or replace function public.link_telegram(
  p_code     text,
  p_chat_id  bigint,
  p_username text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.telegram_link_codes;
begin
  select * into v_row
    from public.telegram_link_codes
   where code = upper(btrim(p_code))
     and used_at is null
   for update;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'code_invalid');
  end if;

  if v_row.expires_at < now() then
    return jsonb_build_object('ok', false, 'reason', 'code_expired');
  end if;

  -- A Telegram account belongs to one profile at a time.
  update public.profiles
     set telegram_chat_id = null, telegram_username = null, telegram_linked_at = null
   where telegram_chat_id = p_chat_id and id <> v_row.user_id;

  update public.profiles
     set telegram_chat_id = p_chat_id,
         telegram_username = p_username,
         telegram_linked_at = now()
   where id = v_row.user_id;

  update public.telegram_link_codes set used_at = now() where code = v_row.code;

  return jsonb_build_object('ok', true, 'user_id', v_row.user_id);
end;
$$;

revoke execute on function public.link_telegram(text, bigint, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Outbox claim / ack, used by the dispatcher
-- ---------------------------------------------------------------------------
create or replace function public.telegram_claim_notifications(p_limit integer default 20)
returns table (
  notification_id bigint,
  chat_id         bigint,
  kind            text,
  payload         jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Resolve the chat at send time rather than at enqueue time. A buyer who
  -- links their account after an order was delivered still gets the message.
  update public.notifications n
     set chat_id = p.telegram_chat_id
    from public.profiles p
   where n.user_id = p.id
     and n.status = 'pending'
     and n.chat_id is null
     and p.telegram_chat_id is not null;

  -- Give an unlinked buyer a day to link before writing the message off.
  -- Notifications stay in the app either way.
  update public.notifications n
     set status = 'skipped', last_error = 'no_telegram_account'
   where n.status = 'pending'
     and n.chat_id is null
     and n.created_at < now() - interval '24 hours';

  -- Anything stuck in 'sending' means a dispatcher died mid-flight.
  update public.notifications n
     set status = 'pending', last_error = 'requeued_after_timeout'
   where n.status = 'sending' and n.attempts < 5;

  return query
  with claimed as (
    select n2.id
      from public.notifications n2
     where n2.status = 'pending'
       and n2.chat_id is not null
       and n2.attempts < 5
     order by n2.created_at
     limit p_limit
     for update skip locked
  )
  update public.notifications n3
     set status = 'sending', attempts = n3.attempts + 1
    from claimed c
   where n3.id = c.id
  returning n3.id, n3.chat_id, n3.kind, n3.payload;
end;
$$;

revoke execute on function public.telegram_claim_notifications(integer)
  from public, anon, authenticated;

create or replace function public.telegram_ack_notification(
  p_id     bigint,
  p_ok     boolean,
  p_error  text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.notifications
     set status = case
                    when p_ok then 'sent'
                    when attempts >= 5 then 'failed'
                    else 'pending'
                  end,
         last_error = p_error,
         sent_at = case when p_ok then now() else sent_at end
   where id = p_id;
end;
$$;

revoke execute on function public.telegram_ack_notification(bigint, boolean, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- What the bot is allowed to read back to a chat
-- ---------------------------------------------------------------------------
create or replace function public.telegram_orders_for_chat(
  p_chat_id bigint,
  p_limit   integer default 5
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(x), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'order_no', o.order_no,
      'status', o.status,
      'total_usd', o.total_usd,
      'created_at', o.created_at,
      'items', (
        select coalesce(jsonb_agg(oi.product_name || ' x' || oi.qty), '[]'::jsonb)
          from public.order_items oi where oi.order_id = o.id
      )
    ) as x
    from public.orders o
    join public.profiles p on p.id = o.user_id
   where p.telegram_chat_id = p_chat_id
   order by o.created_at desc
   limit p_limit
  ) t;
$$;

revoke execute on function public.telegram_orders_for_chat(bigint, integer)
  from public, anon, authenticated;

create or replace function public.telegram_order_by_no(
  p_chat_id  bigint,
  p_order_no text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'order_no', o.order_no,
    'status', o.status,
    'total_usd', o.total_usd,
    'created_at', o.created_at,
    'items', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'name', oi.product_name,
        'qty', oi.qty,
        'delivery_status', oi.delivery_status,
        'codes', coalesce((
          select jsonb_agg(private.decrypt_payload(s.payload_enc) order by s.sold_at)
            from private.stock_items s
           where s.order_id = o.id and s.variant_id = oi.variant_id and s.status = 'sold'
        ), '[]'::jsonb)
      )), '[]'::jsonb)
      from public.order_items oi where oi.order_id = o.id
    )
  )
  from public.orders o
  join public.profiles p on p.id = o.user_id
 where p.telegram_chat_id = p_chat_id
   and upper(o.order_no) = upper(btrim(p_order_no))
   and o.status in ('paid', 'delivering', 'delivered')
  limit 1;
$$;

revoke execute on function public.telegram_order_by_no(bigint, text)
  from public, anon, authenticated;

create or replace function public.telegram_profile_for_chat(p_chat_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'user_id', p.id,
    'display_name', p.display_name,
    'wallet_balance', p.wallet_balance,
    'coins', p.coins,
    'linked_at', p.telegram_linked_at
  )
  from public.profiles p
  where p.telegram_chat_id = p_chat_id
  limit 1;
$$;

revoke execute on function public.telegram_profile_for_chat(bigint)
  from public, anon, authenticated;

create or replace function public.telegram_unlink(p_chat_id bigint)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  update public.profiles
     set telegram_chat_id = null, telegram_username = null, telegram_linked_at = null
   where telegram_chat_id = p_chat_id;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke execute on function public.telegram_unlink(bigint)
  from public, anon, authenticated;
