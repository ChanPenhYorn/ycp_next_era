-- ============================================================================
-- Digital goods storefront - core schema
-- Target: Supabase (Postgres 16)
-- ============================================================================

create schema if not exists extensions;
create extension if not exists "pgcrypto" with schema extensions;

-- The stock vault calls extensions.pgp_sym_encrypt explicitly, because every
-- function runs with `set search_path = ''`. If pgcrypto ever lives in a
-- different schema, encryption would fail at the worst possible moment: when a
-- buyer pays and stock is being written. Fail at migration time instead.
do $$
declare v_schema text;
begin
  select n.nspname into v_schema
    from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
   where e.extname = 'pgcrypto';

  if v_schema is distinct from 'extensions' then
    raise exception
      'pgcrypto is installed in schema "%", expected "extensions". '
      'Run: drop extension pgcrypto; create extension pgcrypto with schema extensions;',
      coalesce(v_schema, '<not installed>');
  end if;
end $$;

-- Private schema: never exposed through PostgREST.
create schema if not exists private;
revoke all on schema private from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.product_kind as enum ('instant_stock', 'auto_topup', 'manual_setup');
create type public.stock_status as enum ('available', 'reserved', 'sold', 'void');
create type public.order_status as enum (
  'pending', 'paid', 'delivering', 'delivered', 'failed', 'refunded', 'expired'
);
create type public.delivery_status as enum ('pending', 'delivered', 'failed', 'manual_waiting');
create type public.payment_provider as enum ('payway', 'khqr_direct', 'wallet', 'manual');
create type public.payment_status as enum ('initiated', 'pending', 'succeeded', 'failed', 'expired', 'refunded');
create type public.wallet_kind as enum ('topup', 'purchase', 'refund', 'admin_adjust', 'coin_reward');
create type public.app_role as enum ('customer', 'staff', 'admin');

-- ---------------------------------------------------------------------------
-- Platform settings (single row, id = true)
-- ---------------------------------------------------------------------------
create table public.settings (
  id                    boolean primary key default true check (id),
  site_name             text not null default 'YCP Store',
  support_telegram      text,
  support_email         text,
  usd_to_khr            numeric(12, 2) not null default 4100,
  order_ttl_minutes     integer not null default 15,
  payway_merchant_id    text,
  khqr_account_id       text,        -- Bakong account id shown in the QR
  khqr_merchant_name    text,
  khqr_merchant_city    text default 'Phnom Penh',
  is_maintenance        boolean not null default false,
  updated_at            timestamptz not null default now()
);

insert into public.settings (id) values (true) on conflict do nothing;

-- Secret key material. Separate table so it can be locked down hard.
create table private.secrets (
  name  text primary key,
  value text not null
);

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  display_name   text,
  phone          text,
  locale         text not null default 'km',
  role           public.app_role not null default 'customer',
  wallet_balance numeric(12, 2) not null default 0 check (wallet_balance >= 0),
  coins          integer not null default 0 check (coins >= 0),
  referral_code  text unique,
  referred_by    uuid references public.profiles (id) on delete set null,
  is_blocked     boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index profiles_referral_code_idx on public.profiles (referral_code);

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------
create table public.categories (
  id          bigint generated always as identity primary key,
  slug        text not null unique,
  name_km     text not null,
  name_en     text not null,
  icon_url    text,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create table public.products (
  id            bigint generated always as identity primary key,
  category_id   bigint references public.categories (id) on delete set null,
  slug          text not null unique,
  name_km       text not null,
  name_en       text not null,
  summary_km    text,
  summary_en    text,
  description_km text,
  description_en text,
  image_url     text,
  kind          public.product_kind not null default 'instant_stock',
  -- Which fields the buyer must fill before paying (e.g. ["game_id","server_id"])
  requires_fields jsonb not null default '[]'::jsonb,
  is_active     boolean not null default true,
  is_featured   boolean not null default false,
  sort_order    integer not null default 0,
  rating_avg    numeric(3, 2) not null default 0,
  rating_count  integer not null default 0,
  sold_count    integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index products_category_idx on public.products (category_id) where is_active;
create index products_featured_idx on public.products (sort_order) where is_active and is_featured;

create table public.product_variants (
  id                   bigint generated always as identity primary key,
  product_id           bigint not null references public.products (id) on delete cascade,
  sku                  text not null unique,
  label_km             text not null,
  label_en             text not null,
  price_usd            numeric(12, 2) not null check (price_usd >= 0),
  compare_at_price_usd numeric(12, 2) check (compare_at_price_usd >= 0),
  cost_usd             numeric(12, 2) not null default 0,
  -- 'stock'   -> count comes from stock_items
  -- 'unlimited' -> always purchasable (top-up delivered through a supplier API)
  stock_mode           text not null default 'stock' check (stock_mode in ('stock', 'unlimited')),
  min_qty              integer not null default 1 check (min_qty > 0),
  max_qty              integer not null default 10 check (max_qty >= min_qty),
  is_active            boolean not null default true,
  sort_order           integer not null default 0,
  created_at           timestamptz not null default now()
);

create index product_variants_product_idx on public.product_variants (product_id) where is_active;

-- ---------------------------------------------------------------------------
-- Stock vault (service-role only)
-- ---------------------------------------------------------------------------
create table private.stock_items (
  id            bigint generated always as identity primary key,
  variant_id    bigint not null references public.product_variants (id) on delete cascade,
  -- Encrypted with private.secrets['stock_key']; never plaintext at rest.
  payload_enc   bytea not null,
  status        public.stock_status not null default 'available',
  order_id      uuid,
  reserved_at   timestamptz,
  sold_at       timestamptz,
  created_at    timestamptz not null default now()
);

create index stock_items_pick_idx
  on private.stock_items (variant_id, created_at)
  where status = 'available';

create index stock_items_order_idx on private.stock_items (order_id) where order_id is not null;

-- ---------------------------------------------------------------------------
-- Orders
-- ---------------------------------------------------------------------------
create table public.orders (
  id              uuid primary key default gen_random_uuid(),
  order_no        text not null unique,
  user_id         uuid not null references public.profiles (id) on delete restrict,
  status          public.order_status not null default 'pending',
  currency        text not null default 'USD',
  subtotal_usd    numeric(12, 2) not null default 0,
  discount_usd    numeric(12, 2) not null default 0,
  total_usd       numeric(12, 2) not null default 0,
  coupon_code     text,
  contact_email   text,
  contact_telegram text,
  customer_note   text,
  -- Snapshot of the fields the buyer filled (game id, server, etc.)
  customer_fields jsonb not null default '{}'::jsonb,
  expires_at      timestamptz not null default (now() + interval '15 minutes'),
  paid_at         timestamptz,
  delivered_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index orders_user_idx on public.orders (user_id, created_at desc);
create index orders_status_idx on public.orders (status) where status in ('pending', 'paid', 'delivering');
create index orders_pending_expiry_idx on public.orders (expires_at) where status = 'pending';

create table public.order_items (
  id             bigint generated always as identity primary key,
  order_id       uuid not null references public.orders (id) on delete cascade,
  variant_id     bigint references public.product_variants (id) on delete set null,
  product_name   text not null,
  variant_label  text not null,
  unit_price_usd numeric(12, 2) not null,
  qty            integer not null check (qty > 0),
  line_total_usd numeric(12, 2) not null,
  unit_cost_usd  numeric(12, 2) not null default 0,
  delivery_status public.delivery_status not null default 'pending',
  delivered_at   timestamptz,
  supplier_ref   text,
  created_at     timestamptz not null default now()
);

create index order_items_order_idx on public.order_items (order_id);
create index order_items_pending_idx on public.order_items (delivery_status)
  where delivery_status <> 'delivered';

-- ---------------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------------
create table public.payments (
  id             bigint generated always as identity primary key,
  order_id       uuid not null references public.orders (id) on delete cascade,
  provider       public.payment_provider not null,
  status         public.payment_status not null default 'initiated',
  amount_usd     numeric(12, 2) not null,
  amount_khr     numeric(14, 2),
  -- PayWay tran_id / Bakong md5 hash
  provider_ref   text,
  provider_hash  text,
  payway_method  text,
  raw_payload    jsonb,
  initiated_at   timestamptz not null default now(),
  verified_at    timestamptz
);

create unique index payments_provider_ref_idx
  on public.payments (provider, provider_ref)
  where provider_ref is not null;

create index payments_order_idx on public.payments (order_id);

-- ---------------------------------------------------------------------------
-- Wallet ledger (double-entry style, append only)
-- ---------------------------------------------------------------------------
create table public.wallet_transactions (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  kind          public.wallet_kind not null,
  amount_usd    numeric(12, 2) not null,
  balance_after numeric(12, 2) not null,
  order_id      uuid references public.orders (id) on delete set null,
  payment_id    bigint references public.payments (id) on delete set null,
  note          text,
  created_at    timestamptz not null default now()
);

create index wallet_tx_user_idx on public.wallet_transactions (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Coupons
-- ---------------------------------------------------------------------------
create table public.coupons (
  id             bigint generated always as identity primary key,
  code           text not null unique,
  kind           text not null check (kind in ('percent', 'fixed')),
  value          numeric(12, 2) not null check (value > 0),
  min_order_usd  numeric(12, 2) not null default 0,
  max_uses       integer,
  used_count     integer not null default 0,
  per_user_limit integer not null default 1,
  starts_at      timestamptz not null default now(),
  expires_at     timestamptz,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

create table public.coupon_redemptions (
  id         bigint generated always as identity primary key,
  coupon_id  bigint not null references public.coupons (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  order_id   uuid not null references public.orders (id) on delete cascade,
  amount_usd numeric(12, 2) not null,
  created_at timestamptz not null default now(),
  unique (coupon_id, order_id)
);

-- ---------------------------------------------------------------------------
-- Reviews
-- ---------------------------------------------------------------------------
create table public.reviews (
  id              bigint generated always as identity primary key,
  product_id      bigint not null references public.products (id) on delete cascade,
  user_id         uuid not null references public.profiles (id) on delete cascade,
  order_id        uuid references public.orders (id) on delete set null,
  rating          integer not null check (rating between 1 and 5),
  body            text,
  is_approved     boolean not null default false,
  coin_rewarded   boolean not null default false,
  created_at      timestamptz not null default now(),
  unique (product_id, user_id, order_id)
);

create index reviews_product_idx on public.reviews (product_id) where is_approved;

-- ---------------------------------------------------------------------------
-- Supplier integrations (auto-restock lane)
-- ---------------------------------------------------------------------------
create table public.suppliers (
  id             bigint generated always as identity primary key,
  code           text not null unique,        -- 'fazercards' | 'foxreload' | 'marix' | 'reloadly'
  name           text not null,
  base_url       text,
  is_active      boolean not null default false,
  created_at     timestamptz not null default now()
);

create table public.supplier_skus (
  id               bigint generated always as identity primary key,
  supplier_id      bigint not null references public.suppliers (id) on delete cascade,
  variant_id       bigint not null references public.product_variants (id) on delete cascade,
  supplier_sku     text not null,
  cost_usd         numeric(12, 2) not null default 0,
  is_active        boolean not null default true,
  last_synced_at   timestamptz,
  last_cost_usd    numeric(12, 2),
  unique (supplier_id, variant_id, supplier_sku)
);

-- ---------------------------------------------------------------------------
-- Audit trail
-- ---------------------------------------------------------------------------
create table public.audit_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid,
  action      text not null,
  entity      text,
  entity_id   text,
  detail      jsonb,
  created_at  timestamptz not null default now()
);

create index audit_log_entity_idx on public.audit_log (entity, entity_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Stock rollup view (counts only, never the payload).
-- Runs as the view owner so it can read private.stock_items; the where clause
-- keeps inactive variants out of the public surface.
-- ---------------------------------------------------------------------------
create or replace view public.variant_stock as
select
  v.id                                   as variant_id,
  v.product_id,
  case when v.stock_mode = 'unlimited' then null
       else count(s.id) filter (where s.status = 'available')
  end                                    as in_stock
from public.product_variants v
left join private.stock_items s on s.variant_id = v.id and s.status = 'available'
where v.is_active
group by v.id, v.product_id, v.stock_mode;

-- Safe slice of settings for the storefront (no merchant credentials).
create or replace view public.public_settings as
select
  id,
  site_name,
  support_telegram,
  support_email,
  usd_to_khr,
  order_ttl_minutes,
  khqr_account_id,
  khqr_merchant_name,
  khqr_merchant_city,
  is_maintenance
from public.settings;

-- Display names for reviews. Deliberately narrow: id + display name only.
create or replace view public.profile_names as
select id, display_name from public.profiles;

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
create or replace function private.touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger products_touch before update on public.products
  for each row execute function private.touch_updated_at();
create trigger orders_touch before update on public.orders
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- New auth user -> profile
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, referral_code)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)),
    upper(substr(replace(new.id::text, '-', ''), 1, 8))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();
