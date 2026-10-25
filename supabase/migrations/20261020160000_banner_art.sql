-- Banner art for the home spotlight.
--
-- A supplier game arrives with one square image (`products.image_url`), which
-- is right for a card but wrong for the wide panel at the top of home: cropped
-- to fit it loses the logo, contained it leaves dead space.
--
-- `banner_url` holds a wide, mirrored image instead. It is resolved by the
-- `game-banner` Edge Function from IGDB key art, or set by staff with an
-- explicit URL, and copied into the `product-images` bucket so the browser can
-- load it (IGDB lets us hotlink, but the mirror keeps us independent of them).
--
-- Null is normal: the spotlight falls back to the square art on a blurred
-- backdrop. Nothing reads this yet at order time, so it is display-only.
alter table public.products
  add column if not exists banner_url text;

comment on column public.products.banner_url is
  'Wide banner art for the home spotlight. Mirrored into product-images; null falls back to image_url.';
