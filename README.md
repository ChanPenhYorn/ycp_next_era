# YCP Store

Khmer-first digital storefront: game top-ups and gift cards, paid with **ABA KHQR**, delivered instantly.

Flutter (web + Android + iOS) on a Supabase backend. No separate app server.

```
app/                      Flutter client (Riverpod + go_router)
  lib/src/core/           env, theme, router, formatting
  lib/src/data/           repositories (catalog, orders, payments)
  lib/src/state/          Riverpod providers, cart, locale
  lib/src/ui/             pages and widgets
  lib/l10n/               Khmer (default) + English ARB files

supabase/
  migrations/             schema, RLS, business-logic RPCs
  functions/              PayWay Edge Functions (holds the API key)
  tests/                  local Postgres test harness
```

## Why the money logic is where it is

Three rules shape the whole design. Breaking any of them is how these stores lose money.

1. **Every price, stock check and coupon rule is resolved in Postgres.** `create_order` recomputes totals from the catalogue; the client's numbers are only ever a preview. A tampered app cannot buy a $10 code for $0.01.
2. **The PayWay API key never leaves the server.** It lives in Supabase Edge Function secrets. The app receives a QR string and a status, nothing else. `payway-init` builds the hash and calls ABA; `payway-verify` polls and settles.
3. **ABA is asked, never believed.** The `return_url` pushback is unsigned, so `payway-callback` only uses it to learn *which* order to look at. The decision to deliver comes from `check-transaction`, plus an amount check so an underpayment never ships goods.

Stock delivery is a single atomic statement, so two buyers can never be sold the same code:

```sql
update private.stock_items s
   set status = 'sold', order_id = p_order_id, sold_at = now()
 where s.id in (
   select id from private.stock_items
    where variant_id = v_item.variant_id and status = 'available'
    order by created_at
    limit v_item.qty
    for update skip locked
 );
```

If fewer rows come back than were ordered, the pick is rolled back and the line moves to the manual queue. Nothing is silently lost.

## Setup

### 1. Supabase

```bash
supabase start                       # local stack
supabase db reset                    # applies supabase/migrations
psql "$DB_URL" -f supabase/tests/local_bootstrap.sql   # local-only stubs
psql "$DB_URL" -f supabase/tests/seed_catalog.sql      # demo catalogue + stock
```

For a hosted project, `supabase db push` applies the same migrations.

### 2. PayWay

Register a sandbox account at <https://sandbox.payway.com.kh/register-sandbox/>. You get a merchant id and API key by email.

```bash
supabase secrets set --env-file .env
```

Set `PAYWAY_ENV`, `PAYWAY_MERCHANT_ID`, `PAYWAY_API_KEY`. Production credentials come from `paywaysales@ababank.com`.

Then whitelist the callback URL in the PayWay merchant profile:

```
https://<project-ref>.supabase.co/functions/v1/payway-callback
```

`payway-callback` runs with `verify_jwt = false` in `supabase/config.toml` because ABA has no Supabase JWT. That is safe: the function does not act on the pushback contents.

### 3. Flutter

```bash
cd app
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
```

`flutter run -d chrome` for web, or pick a device. Only the client-safe key goes in the app.

### 4. Verify the database layer

The money logic has a runnable test harness that needs nothing but Docker:

```bash
supabase/tests/run.sh
```

It creates a throwaway Postgres 16, applies the migrations, seeds a catalogue and asserts the things that matter: RLS isolation, the oversell guard, quantity limits, required buyer fields, coupon limits, the wallet ledger, and the short-pick rollback.

## Stages

`[x]` verified, `[~]` scaffolded and compiling but not yet exercised against live ABA, `[ ]` not started.

| # | Stage | State |
|---|---|---|
| 0 | Schema, RLS, RPCs, atomic stock delivery, wallet ledger | `[x]` |
| 1 | PayWay adapter: purchase hash, check-transaction, callback verify | `[x]` |
| 2 | Flutter shell: Khmer/English i18n, theme, routing, Riverpod state | `[x]` |
| 3 | Catalogue: home, category filter, search, product detail, reviews | `[~]` |
| 4 | Cart + checkout, coupon preview, wallet payment | `[~]` |
| 5 | **Native KHQR sheet**: render QR, deep-link to ABA Mobile, poll and settle | `[~]` |
| 6 | Orders: history, detail, reveal codes | `[~]` |
| 7 | Auth: passwordless email OTP | `[~]` |
| 8 | Admin surface: add stock, resolve manual items, product CRUD | `[ ]` |
| 9 | Supplier auto-restock: FazerCards / FoxReload / Marix adapters + price sync | `[ ]` |
| 10 | Growth: coins, referrals, review rewards, flash-sale banners | `[ ]` |
| 11 | Ops: pg_cron expiry sweep, backups, uptime alerts, fraud velocity rules | `[ ]` |
| 12 | Telegram bot for order status and support handoff | `[ ]` |
| 13 | Play Store / App Store submission, Khmer store listing | `[ ]` |

Stage 5 is the one to exercise next: it needs live sandbox credentials, and payment flows are where assumptions go to die.

## Sourcing

Read this before adding a SKU.

`settings` and the catalogue are agnostic about where inventory comes from, so the technical work here is valid either way. The business decision is separate, and it is the one that decides whether the store survives.

Source from a wholesale channel with a contract and an API: game keys and top-ups from FazerCards, FoxReload, Marix or Reloadly; software subscriptions from a real distributor such as Pax8 or Ingram Micro. Two habits keep the store alive: never list a SKU you cannot source from a contract, and never price below wholesale. Deep discounts usually mean grey or fraud-sourced codes, and those get revoked after you have sold them, which you then pay for twice in refunds and reviews.

Netflix, Spotify, YouTube, Canva and CapCut run no reseller programme. A store selling those at $0.50-$2.50 is reselling pooled or fraudulently created accounts. That is account-sharing fraud at best and handling stolen goods at worst, and it ends in revoked inventory, chargebacks, a terminated PayWay merchant account and liability for the seller rather than the buyer. The same build supports gift cards, game top-ups and real software subscriptions without that exposure.

## Notes

- Product images: `product-images` is a public storage bucket, configured in `supabase/config.toml`.
- Stock payloads are encrypted at rest with `pgp_sym_encrypt`. The key lives in `private.secrets`; only `reveal_order` can decrypt, and it re-checks ownership and paid status on every call.
- `supabase/tests/` is a local harness, not part of the deployed schema.
