-- Dodo checkout bookkeeping.
--
-- A Dodo payment has two identifiers, and they appear at different times:
--
--   * `cks_...` the checkout session, returned when the session is created.
--     It is what the app polls, because the payment id does not exist until
--     the buyer has actually paid.
--   * `pay_...` the payment, returned by the webhook and by the session once
--     it succeeds. This is the id that settles the order, so it goes in
--     `provider_ref`, which already carries the unique index that makes
--     settlement idempotent.
--
-- `provider_session_id` therefore gets its own column. Reusing `provider_ref`
-- for both would either collide on the unique index or leave a pending row
-- whose id silently changes under it.
alter table public.payments
  add column if not exists provider_session_id text;

comment on column public.payments.provider_session_id is
  'Dodo checkout session id (cks_...). provider_ref holds the payment id (pay_...) once it exists.';

create unique index if not exists payments_provider_session_idx
  on public.payments (provider, provider_session_id)
  where provider_session_id is not null;

-- The card option is opt-in. A fresh project has no Dodo keys, and a payment
-- tile that always fails is worse than no tile at all. Staff flip this on once
-- the product and keys exist.
alter table public.settings
  add column if not exists dodo_enabled boolean not null default false;

comment on column public.settings.dodo_enabled is
  'Show the card (Dodo) payment option at checkout. Requires DODO_* Edge secrets and a Pay What You Want product.';

-- The app reads the view, not the table.
create or replace view public.public_settings as
select
  id, site_name, support_telegram, support_email, usd_to_khr, order_ttl_minutes,
  khqr_account_id, khqr_merchant_name, khqr_merchant_city, is_maintenance,
  topup_min_usd, topup_max_usd, telegram_bot_username, manual_grace_minutes,
  dodo_enabled
from public.settings;

grant select on public.public_settings to anon, authenticated;
