-- ABA KHQR can be switched off once the card rail is live.
--
-- The storefront reports this through `public_settings`, so the checkout stops
-- drawing a payment button the project cannot honour. Default true: an existing
-- deployment keeps taking KHQR until staff deliberately turn it off.
alter table public.settings
  add column if not exists khqr_enabled boolean not null default true;

comment on column public.settings.khqr_enabled is
  'Show the ABA KHQR option at checkout and on a pending order. Turn off when Dodo card payments are live and ABA is retired.';

create or replace view public.public_settings as
select
  id, site_name, support_telegram, support_email, usd_to_khr, order_ttl_minutes,
  khqr_account_id, khqr_merchant_name, khqr_merchant_city, is_maintenance,
  topup_min_usd, topup_max_usd, telegram_bot_username, manual_grace_minutes,
  dodo_enabled, khqr_enabled
from public.settings;

grant select on public.public_settings to anon, authenticated;
