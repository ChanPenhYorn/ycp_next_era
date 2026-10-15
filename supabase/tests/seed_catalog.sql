-- ============================================================================
-- Seed catalogue + stock for local verification.
-- Run after the migrations and after local_bootstrap.sql.
-- ============================================================================

-- Encryption key for the stock vault.
insert into private.secrets (name, value)
values ('stock_key', 'local-dev-key-do-not-use-in-production')
on conflict (name) do update set value = excluded.value;

-- Public contact settings.
update public.settings
   set site_name        = 'Sela',
       support_telegram = 'https://t.me/example',
       usd_to_khr       = 4100,
       khqr_account_id  = 'sela@aclb',
       khqr_merchant_name = 'SELA',
       telegram_bot_username = 'ycp_store_bot';

insert into public.categories (slug, name_km, name_en, sort_order) values
  ('game-topup', 'បញ្ចូលពេជ្រហ្គេម', 'Game Top-Up', 1),
  ('gift-card',  'កាតអំណោយ',        'Gift Cards', 2)
on conflict (slug) do nothing;

insert into public.products (
  category_id, slug, name_km, name_en, summary_km, summary_en,
  image_url, kind, requires_fields, is_featured, sort_order
) values
  ((select id from public.categories where slug = 'game-topup'),
   'mobile-legends-diamonds', 'ពេជ្រ Mobile Legends', 'Mobile Legends Diamonds',
   'បញ្ចូលពេជ្ររហ័ស', 'Instant diamond top-up',
   '/images/products/mlbb.webp', 'auto_topup',
   '[{"key":"userid","label_km":"លេខ ID ហ្គេម","label_en":"Game ID","pattern":"^[0-9]{6,12}$"},
     {"key":"serverid","label_km":"Server","label_en":"Server","pattern":"^[0-9]{3,6}$"}]'::jsonb,
   true, 1),
  ((select id from public.categories where slug = 'gift-card'),
   'steam-wallet-code', 'កាត Steam', 'Steam Wallet Code',
   'កូដ Steam ផ្លូវការ', 'Official Steam wallet code',
   '/images/products/steam.webp', 'instant_stock',
   '[]'::jsonb, true, 2)
on conflict (slug) do nothing;

insert into public.product_variants (product_id, sku, label_km, label_en, price_usd, compare_at_price_usd, cost_usd, stock_mode, min_qty, max_qty) values
  ((select id from public.products where slug = 'mobile-legends-diamonds'), 'MLBB-86',  '៨៦ ពេជ្រ',  '86 Diamonds',  0.99, 1.20, 0.82, 'unlimited', 1, 20),
  ((select id from public.products where slug = 'mobile-legends-diamonds'), 'MLBB-172', '១៧២ ពេជ្រ', '172 Diamonds', 1.89, 2.30, 1.62, 'unlimited', 1, 20),
  ((select id from public.products where slug = 'steam-wallet-code'), 'STEAM-5',  'Steam $5',  'Steam $5',  5.50, 6.00, 5.05, 'stock', 1, 5),
  ((select id from public.products where slug = 'steam-wallet-code'), 'STEAM-10', 'Steam $10', 'Steam $10', 10.90, 12.00, 10.10, 'stock', 1, 5)
on conflict (sku) do nothing;

insert into public.coupons (code, kind, value, min_order_usd, max_uses, per_user_limit)
values ('WELCOME10', 'percent', 10, 1.00, 1000, 1)
on conflict (code) do nothing;

-- Three Steam $5 codes in the vault, encrypted exactly like production does.
-- admin_add_stock is staff-gated, so seed an admin and act as them.
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'admin@example.test', '{"display_name":"Admin"}'::jsonb),
  ('22222222-2222-2222-2222-222222222222', 'buyer@example.test', '{"display_name":"Buyer"}'::jsonb)
on conflict (id) do nothing;

update public.profiles
   set role = 'admin'
 where id = '11111111-1111-1111-1111-111111111111';

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

select public.admin_add_stock(
  (select id from public.product_variants where sku = 'STEAM-5'),
  array['steam-code-AAAA-1111', 'steam-code-BBBB-2222', 'steam-code-CCCC-3333']
) as stock_added;
