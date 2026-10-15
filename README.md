# ycp_next_era

Khmer-first digital goods store: game top-ups and gift cards with ABA KHQR checkout.

## Layout

- `app/` — Flutter client (`ycp_store`). Catalog, cart, checkout, orders, KHQR payment sheet. English/Khmer localization via ARB files.
- `supabase/migrations/` — Postgres schema, row level security, and RPC definitions.
- `supabase/functions/` — Edge functions for the Payway payment flow (`payway-init`, `payway-verify`, `payway-callback`).
- `supabase/tests/` — Local bootstrap helpers.
- `.env.example` — Required environment variables.

## Flutter client

```bash
cd app
flutter pub get
flutter run
```

## Supabase

```bash
supabase start
supabase db reset
supabase functions serve
```

Set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `PAYWAY_ENV`, `PAYWAY_MERCHANT_ID`, and `PAYWAY_API_KEY` as function secrets.
