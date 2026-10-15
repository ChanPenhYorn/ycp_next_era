-- ============================================================================
-- Demo data for a fresh project.
--
-- Two ways in. Locally `supabase/config.toml` points [db.seed] at this file, so
-- `supabase db reset` loads it. For a hosted project, paste it into the SQL
-- editor AFTER supabase/migrations/combined.sql.
--
-- Unlike supabase/tests/seed_catalog.sql, this touches no auth tables, so it is
-- safe to run against a hosted project.
--
-- Delete it before going live:
--   truncate public.order_items, public.orders, public.reviews cascade;
--   delete from public.product_variants;
--   delete from public.products;
--   delete from public.categories;
--   delete from private.stock_items;
-- ============================================================================

-- A random vault key per environment. Never reuse a demo key in production.
insert into private.secrets (name, value)
values ('stock_key', encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (name) do nothing;

update public.settings
   set site_name             = 'Sela',
       support_telegram      = 'https://t.me/ycp_store_bot',
       telegram_bot_username = 'ycp_store_bot',
       usd_to_khr            = 4100,
       khqr_account_id       = 'sela@aclb',
       khqr_merchant_name    = 'SELA',
       topup_min_usd         = 1,
       topup_max_usd         = 1000
 where id;

insert into public.categories (slug, name_km, name_en, sort_order) values
  ('game-topup', 'បញ្ចូលពេជ្រហ្គេម', 'Game Top-Up', 1),
  ('gift-card',  'កាតអំណោយ',        'Gift Cards',  2),
  ('vpn',        'VPN និងសុវត្ថិភាព', 'VPN & Security', 3)
on conflict (slug) do nothing;

insert into public.products (
  category_id, slug, name_km, name_en, summary_km, summary_en,
  description_km, description_en, kind, requires_fields, is_featured, sort_order
) values
  ((select id from public.categories where slug = 'game-topup'),
   'mobile-legends-diamonds',
   'ពេជ្រ Mobile Legends', 'Mobile Legends Diamonds',
   'បញ្ចូលពេជ្ររហ័ស ដោយស្វ័យប្រវត្តិ', 'Instant automatic diamond top-up',
   E'បញ្ចូលពេជ្រចូលគណនីរបស់អ្នកដោយស្វ័យប្រវត្តិ។\nសូមបញ្ចូល ID ហ្គេម និង Server ឲ្យត្រឹមត្រូវ។',
   E'Diamonds are credited automatically.\nEnter your Game ID and Server exactly as shown in the game.',
   'auto_topup',
   -- Field KEYS must match the supplier's own names (Bay2Game uses userid and
   -- serverid) or the adapter cannot map them and every order refunds. Labels
   -- are free text, so the buyer still sees "Game ID".
   '[{"key":"userid","label_km":"លេខ ID ហ្គេម","label_en":"Game ID","placeholder":"123456789","pattern":"^[0-9]{6,12}$"},
     {"key":"serverid","label_km":"Server","label_en":"Server","placeholder":"2001","pattern":"^[0-9]{3,6}$"}]'::jsonb,
   true, 1),

  ((select id from public.categories where slug = 'gift-card'),
   'steam-wallet',
   'កាត Steam Wallet', 'Steam Wallet Code',
   'កូដផ្លូវការ ដឹកភ្លាមៗ', 'Official code, delivered instantly',
   E'កូដ Steam Wallet ផ្លូវការ។\nអ្នកនឹងទទួលបានកូដភ្លាមៗបន្ទាប់ពីទូទាត់។',
   E'Official Steam Wallet code.\nYour code appears immediately after payment.',
   'instant_stock', '[]'::jsonb, true, 2),

  ((select id from public.categories where slug = 'gift-card'),
   'google-play-card',
   'កាត Google Play', 'Google Play Gift Card',
   'កូដផ្លូវការ ដឹកភ្លាមៗ', 'Official code, delivered instantly',
   E'កូដ Google Play ផ្លូវការ។',
   E'Official Google Play gift card code.',
   'instant_stock', '[]'::jsonb, false, 3),

  ((select id from public.categories where slug = 'vpn'),
   'nordvpn',
   'កូដ NordVPN', 'NordVPN Activation',
   'ដំឡើងដោយបុគ្គលិក ក្នុងរយៈពេល ១៥ នាទី', 'Staff activated within 15 minutes',
   E'យើងនឹងដំឡើងឲ្យអ្នកក្នុងរយៈពេល ១៥ នាទី។',
   E'We activate this for you within 15 minutes.',
   'manual_setup', '[]'::jsonb, false, 4)
on conflict (slug) do nothing;

insert into public.product_variants (
  product_id, sku, label_km, label_en, price_usd, compare_at_price_usd, cost_usd,
  stock_mode, min_qty, max_qty, sort_order
) values
  ((select id from public.products where slug = 'mobile-legends-diamonds'),
   'MLBB-86',  '៨៦ ពេជ្រ',  '86 Diamonds',  0.99, 1.20, 0.82, 'unlimited', 1, 20, 1),
  ((select id from public.products where slug = 'mobile-legends-diamonds'),
   'MLBB-172', '១៧២ ពេជ្រ', '172 Diamonds', 1.89, 2.30, 1.62, 'unlimited', 1, 20, 2),
  ((select id from public.products where slug = 'mobile-legends-diamonds'),
   'MLBB-355', '៣៥៥ ពេជ្រ', '355 Diamonds', 3.79, 4.50, 3.35, 'unlimited', 1, 20, 3),

  ((select id from public.products where slug = 'steam-wallet'),
   'STEAM-5',  'Steam $5',  'Steam $5',  5.50,  6.00,  5.05, 'stock', 1, 5, 1),
  ((select id from public.products where slug = 'steam-wallet'),
   'STEAM-10', 'Steam $10', 'Steam $10', 10.90, 12.00, 10.10, 'stock', 1, 5, 2),
  ((select id from public.products where slug = 'steam-wallet'),
   'STEAM-20', 'Steam $20', 'Steam $20', 21.50, 24.00, 20.10, 'stock', 1, 5, 3),

  ((select id from public.products where slug = 'google-play-card'),
   'GPLAY-10', 'Google Play $10', 'Google Play $10', 10.60, 12.00, 10.05, 'stock', 1, 5, 1),

  ((select id from public.products where slug = 'nordvpn'),
   'NORD-1Y',  '១ ឆ្នាំ',  '1 Year',  12.50, 18.00, 10.00, 'unlimited', 1, 3, 1)
on conflict (sku) do nothing;

-- Vault stock. Encrypted exactly the way a real delivery payload would be.
insert into private.stock_items (variant_id, payload_enc)
select v.id, private.encrypt_payload(code)
from (values
  ('STEAM-5',  'STEAM-DEMO-5A1B-2C3D'),
  ('STEAM-5',  'STEAM-DEMO-5E4F-5A6B'),
  ('STEAM-5',  'STEAM-DEMO-5C7D-8E9F'),
  ('STEAM-10', 'STEAM-DEMO-10A1-B2C3'),
  ('STEAM-10', 'STEAM-DEMO-10D4-E5F6'),
  ('STEAM-20', 'STEAM-DEMO-20A1-B2C3'),
  ('GPLAY-10', 'GPLAY-DEMO-10A1-B2C3'),
  ('GPLAY-10', 'GPLAY-DEMO-10D4-E5F6')
) as seed(sku, code)
join public.product_variants v on v.sku = seed.sku;

-- Placeholder art. Deliberately an external URL rather than a Storage path,
-- because this file must run against any project. placehold.co sends
-- Access-Control-Allow-Origin, which Flutter web's CanvasKit renderer needs.
--
-- Real products get their imagery from the supplier sync, which mirrors it into
-- the product-images bucket. See mirrorImage() in supplier-sync: Bay2Game's CDN
-- sends no CORS header, so hotlinking their art would render on mobile and be
-- invisible in a browser.
update public.products
   set image_url = case slug
     when 'mobile-legends-diamonds' then 'https://placehold.co/600x450/16224a/c3cbe0/png?text=Mobile+Legends'
     when 'steam-wallet'            then 'https://placehold.co/600x450/16224a/c3cbe0/png?text=Steam+Wallet'
     when 'google-play-card'        then 'https://placehold.co/600x450/16224a/c3cbe0/png?text=Google+Play'
     when 'nordvpn'                 then 'https://placehold.co/600x450/16224a/c3cbe0/png?text=NordVPN'
     else image_url
   end
 where image_url is null;

insert into public.coupons (code, kind, value, min_order_usd, max_uses, per_user_limit)
values ('WELCOME10', 'percent', 10, 1.00, 1000, 1)
on conflict (code) do nothing;

select
  (select count(*) from public.categories)       as categories,
  (select count(*) from public.products)         as products,
  (select count(*) from public.product_variants) as variants,
  case when private.stock_key() is null then 'MISSING' else 'set' end as vault_key;
