# Sela

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

Everything below runs against project `ozelquxztpqpjikhgnxd`.

```bash
cp .env.local.example .env.local     # fill in the keys, never commit it
./scripts/setup-supabase.sh
```

That script checks CLI auth, links the project, applies the migrations, uploads the PayWay secrets, deploys the three Edge Functions, and prints the callback URL to register with ABA plus the Flutter run command.

Where each value comes from in the dashboard:

| `.env.local` key | Dashboard location |
|---|---|
| `SUPABASE_PROJECT_REF` | Settings → General → Reference ID |
| `DATABASE_PASSWORD` | Settings → Database → Connection string |
| `SUPABASE_URL` | Settings → API → Project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Settings → API → publishable key (older projects: `anon`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Settings → API → secret key (older projects: `service_role`) |

> The service role key bypasses every RLS policy. It belongs in Edge Function secrets and nowhere else: not in the app bundle, not in a chat, not in git. `.env.local` is already gitignored.

Prefer working entirely offline? The migrations and the demo catalogue both run
locally. `supabase/config.toml` points `[db.seed]` at `seed/demo.sql`, so a reset
seeds the catalogue:

```bash
supabase start
supabase db reset    # migrations, then seed/demo.sql: 4 products, 8 variants, stock, a coupon
```

`supabase/tests/local_bootstrap.sql` and `supabase/tests/seed_catalog.sql` are for
the standalone Postgres harness in `supabase/tests/run.sh`, which has to create the
Supabase roles itself.

### 2. PayWay

Register a sandbox account at <https://sandbox.payway.com.kh/register-sandbox/>. You get a merchant id and API key by email.

```bash
supabase secrets set --env-file .env
```

Set `PAYWAY_ENV`, `PAYWAY_MERCHANT_ID`, `PAYWAY_API_KEY`. Production credentials come from `paywaysales@ababank.com`.

**Locally those belong in `supabase/functions/.env`, not `.env.local`.** `.env.local`
only feeds `supabase secrets set` for the hosted project; local functions read
their own file. Miss that and `payway-init` answers `503 payway_not_configured`
while every credential looks present in `.env.local`. A payment link such as
`link-sandbox.payway.com.kh/<code>` is a hosted checkout page, not credentials —
the API needs the merchant id and API key.

A missing credential is reported as: *"KHQR payments are not switched on for this
project yet."*

### Paying in dev without ABA credentials

`PAYWAY_ENV=stub` in `supabase/functions/.env` stands in for ABA, so checkout, the
QR sheet and settlement all work with nothing to sign up for. Only the ABA
boundary is faked: `payway-init` builds the real request and hash, `settleOrder`
runs its real amount check and `mark_order_paid` is the real RPC, so the order
still goes through its normal path.

The stub refuses to engage outside a local stack (`isLocalRuntime()` in
`_shared/payway.ts`), so a hosted project that sets the name by mistake reports
`payway_not_configured` rather than approving money nobody sent. Its QR strings
begin with `STUB-`, so they cannot be mistaken for payable codes.

Two knobs exercise the failure branches, each needing the stack restarted:

```
PAYWAY_STUB_SETTLE_SECONDS=6   # how long the QR waits before it is approved
PAYWAY_STUB_STATE=DECLINED     # the sheet shows a declined payment
PAYWAY_STUB_UNDERPAY=1         # settlement refuses for underpayment
```

`SETTLE_SECONDS` matters most for the UI. A stub that approves on the first poll
closes the QR sheet the instant it opens (`khqr_sheet.dart` pops on `ok`), which
is what a real ABA payment never does: ABA answers `PENDING` until a human scans.
The default 6s keeps the sheet open long enough to read. Set it to 0 only when you
want the instant path, and remember the same wait does not exist against real ABA —
there the wait is however long your test payment takes.

The underpayment knob matters more than convenience: it is the guard that stops
delivery on a short payment. `./scripts/verify-sandbox.sh --check-payway` proves
both branches and reports the shortfall it refused.

### Two restart rules, because they differ

| Changed | Do this | Why |
|---|---|---|
| An Edge Function's **code** | `./scripts/dev.sh --reload-functions` | the runtime snapshots functions into `/var/tmp` at boot and reuses the stale isolate |
| An Edge Function's **environment** (`supabase/functions/.env`) | `supabase stop && supabase start` | the CLI bakes those values into the container at creation; `docker restart` keeps the old ones |

Then whitelist the callback URL in the PayWay merchant profile:

```
https://<project-ref>.supabase.co/functions/v1/payway-callback
```

`payway-callback` runs with `verify_jwt = false` in `supabase/config.toml` because ABA has no Supabase JWT. That is safe: the function does not act on the pushback contents.

### 3. Flutter

Two configs, one per environment. They are plain `--dart-define-from-file`
files, so the same command works on web, Android and iOS. No native flavors:
`flutter run --flavor` is only honoured on Android, macOS and iOS, and this
project is tested in Chrome, where it is a warning and nothing more.

| File | Target | Sign-in |
|---|---|---|
| `app/config/dev.json` | local stack, `127.0.0.1:54321` | fixed code, no email |
| `app/config/prod.json` | hosted project | real email OTP |

Paths are relative to `app/`, which is the Flutter project root.

```bash
./scripts/dev.sh                  # stack up, seeded, verified, app in Chrome
./scripts/dev.sh -d macos
./scripts/dev.sh --reset          # wipe and re-seed the database first
```

`dev.sh` is idempotent: it checks Docker and the CLI, creates
`supabase/functions/.env` if it is missing, starts the stack, resets the database
only when the catalogue is empty (or on `--reset`), runs the verification below,
then launches the app. The manual equivalent, if you prefer to see each step:

```bash
supabase start                        # dev only
./scripts/run-sandbox.sh -d chrome    # reads config/dev.json

cd app
flutter build web --dart-define-from-file=config/prod.json
```

VS Code gets the same setups in `.vscode/launch.json`: *Sela dev* and
*Sela prod*, each for Chrome and for a device. Use dev while building screens —
a few careless prod runs against the 2-per-hour mailer lock sign-in for the
whole project until the window rolls over.

`./scripts/run-app.sh` still works for the hosted project and reads `.env.local`.
It refuses to start if the publishable key is missing or if it looks like a secret
key — a privileged key compiled into the app bundle would be a full RLS bypass for
anyone who extracts it.

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
| 8 | Wallet top-up (RPC + settlement path) | `[x]` |
| 9 | Scheduled housekeeping: order expiry, rating refresh (`pg_cron`) | `[x]` |
| 10 | Review approval, coin reward, rating recompute | `[x]` |
| 11 | Supplier fulfilment RPCs: claim a job, complete or refund | `[x]` |
| 12 | Supplier worker: `supplier-sync` + `supplier-fulfil`, Bay2Game adapter | `[x]` |
| 12a | KAS Play adapter (218 games, player-nickname validation, gift cards) | `[ ]` |
| 12b | "Verify account" button using supplier player validation | `[ ]` |
| 13 | Admin UI over the existing admin RPCs (stock intake, manual queue, review moderation) | `[ ]` |
| 13a | Telegram: linking, `/orders`, `/order`, `/wallet`, notifications, support handoff | `[x]` |
| 13b | Account screen: profile, coins, Telegram linking, sign out | `[x]` |
| 14 | Wallet UI: balance, top-up via KHQR, ledger | `[x]` |
| 15 | Review UI: write a review from a delivered order, pending-approval notice | `[x]` |
| 16 | Growth: referrals, flash-sale banners, coins redemption | `[ ]` |
| 17 | Ops: backups, uptime alerts, fraud velocity rules | `[ ]` |
| 19 | Play Store / App Store submission, Khmer store listing | `[ ]` |

The database row of this table is the part that is genuinely verified: `supabase/tests/run.sh` asserts RLS isolation, the oversell guard, quantity limits, required buyer fields, coupon limits, the wallet ledger, the short-pick rollback, top-up limits, the review guard, and the supplier refund path.

Stage 5 is the one to exercise next: it needs live sandbox credentials, and payment flows are where assumptions go to die.

## Authentication

Sign-in is Google first, email OTP second. The app asks the project
`GET /auth/v1/settings` at runtime and renders the Google button only when the
provider is enabled, so enabling it in the dashboard needs no app rebuild.

**The email limit is the reason Google matters.** Supabase's built-in mailer
allows **2 emails per hour for the entire project** — not per user. That is
usable for testing and unusable for launch.

| Method | Cost | Limit | Notes |
|---|---|---|---|
| Google | free | none | scopes are non-sensitive, so no Google review |
| Email + custom SMTP | Resend 3k/mo, Brevo 300/day free | generous | set under Authentication → SMTP |
| Email, built-in | free | **2/hour** | testing only |
| Facebook | free | none | dominant in Cambodia |
| Phone / SMS | per message | provider-dependent | needs Twilio/MessageBird |

### Sandbox sign-in

Ordering an email on every test run is unusable, so dev builds sign in with a
fixed code instead. Set `DEV_OTP` in `app/config/dev.json` (already `123456`)
plus the same value in `supabase/functions/.env`, run `supabase start`, and the
`dev-signin` Edge Function returns a real session for that code. Nothing is
emailed, and RLS applies to the session exactly as it does to an emailed one.

The code is ignored unless `SUPABASE_URL` is loopback, checked in
`Env.devAuthEnabled`, so a prod build cannot be made to accept it. Unset `DEV_OTP`
in the function environment and `dev-signin` answers 404.

Proof, rather than assertion:

```bash
./scripts/verify-sandbox.sh                  # 31 checks against the running stack
./scripts/verify-sandbox.sh --check-payway   # also proves the declined and underpaid branches
./scripts/verify-sandbox.sh --check-disabled # also stops/starts the stack to prove the switch
```

It covers the guardrails (wrong code, missing address, wrong method), the sign-in
itself, that the session it hands out is a real one (the signup trigger has run,
the profile is RLS-scoped to that user, an anonymous read is refused outright), the
demo catalogue the home screen renders, and the whole checkout → `payway-init` →
settled-order path. `./scripts/dev.sh` runs the default set before launching.

One trap when changing `DEV_OTP`: the CLI bakes `supabase/functions/.env` into the
container's environment when it creates it (`docker inspect` shows it). A
`docker restart` changes nothing and `supabase start` on a running stack is a
no-op, so use `supabase stop && supabase start`.

**Before launch, on the hosted project:** turn off *Confirm email* under
Authentication → Providers → Email, and add custom SMTP under Authentication →
Emails. With confirmation on, `signInWithOtp` for a new address sends the *Confirm
signup* template, which carries a link and no `{{ .Token }}`, so the app's
six-digit field has nothing to accept.

### Enabling Google

1. Google Cloud → Auth Platform → create an OAuth client (type: Web application).
2. Authorised JavaScript origins: your site URL and `http://localhost:8080`.
3. Authorised redirect URI:
   `https://<project-ref>.supabase.co/auth/v1/callback`
4. Paste the client ID and secret into Authentication → Providers → Google.
5. Add these redirect URLs under Authentication → URL Configuration:
   - `http://localhost:8080`
   - `sela://auth-callback` (mobile deep link, see `Brand.urlScheme`)

For Android you also need a second OAuth client of type Android, registered with
your keystore's SHA-1 fingerprint. There is a different fingerprint for debug
and release, so add both.

## Suppliers

Auto top-ups are fulfilled by a supplier adapter. Adding one is a single file
implementing `SupplierAdapter` in `supabase/functions/_shared/suppliers/`.

Set `BAY2GAME_API_KEY` and `SUPPLIER_JOB_SECRET` in `supabase/functions/.env`
for a local run, or with `supabase secrets set --env-file` for the hosted
project. Putting them only in `.env.local` leaves local syncs answering
`supplier_not_configured`, because that file feeds `secrets set`, not the local
function runtime.

Both workers carry `verify_jwt = true`, so they need an `Authorization` header
*and* the job secret. The key is an ordinary JWT — the publishable key is not
one.

```bash
# Sync a supplier catalogue into your own products and variants.
# Start small: a full sweep is 200+ games and 200+ product calls.
curl -X POST "$FUNCTIONS/supplier-sync" \
  -H "Authorization: Bearer $ANON_JWT" \
  -H "x-job-secret: $SUPPLIER_JOB_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"supplier":"bay2game","limit":3,"dryRun":true}'

# Fulfil orders that are waiting on a supplier.
curl -X POST "$FUNCTIONS/supplier-fulfil" \
  -H "Authorization: Bearer $ANON_JWT" \
  -H "x-job-secret: $SUPPLIER_JOB_SECRET" -d '{"limit":10}'
```

Synced variants are **priced at cost** until staff set a retail price, so an
unpriced SKU cannot be sold at a loss, only at zero margin.

Product art is mirrored into the `product-images` bucket rather than hotlinked,
because the supplier's CDN sends no `Access-Control-Allow-Origin` header and
Flutter web renders images through `fetch`. The mirror writes a URL built from
`STORAGE_PUBLIC_URL`, falling back to `SUPABASE_URL`. Locally `SUPABASE_URL` is
`http://kong:8000`, the compose-network name, which no browser can resolve —
set `STORAGE_PUBLIC_URL=http://127.0.0.1:54321` in `supabase/functions/.env`,
which is what the example file does. Without it the sync reports a `warning`
and the art falls back to the CDN, where it is invisible in a browser.

The worker distinguishes three outcomes, and the distinction is the point:

| Outcome | Effect | Why |
|---|---|---|
| `delivered` | line closed | normal path |
| `refund` | money returned to the buyer's wallet | the order is genuinely undoable |
| `retry` | attempts+, exponential backoff | transient failure, or **the supplier's wallet is empty** |

Running out of supplier balance must never refund a buyer who paid correctly,
and must never silently drop the order either. After five attempts the line
escalates to `manual_waiting` for staff, and the buyer's money has still not
moved.

## Sourcing

Read this before adding a SKU.

`settings` and the catalogue are agnostic about where inventory comes from, so the technical work here is valid either way. The business decision is separate, and it is the one that decides whether the store survives.

Source from a wholesale channel with a contract and an API: game keys and top-ups from FazerCards, FoxReload, Marix or Reloadly; software subscriptions from a real distributor such as Pax8 or Ingram Micro. Two habits keep the store alive: never list a SKU you cannot source from a contract, and never price below wholesale. Deep discounts usually mean grey or fraud-sourced codes, and those get revoked after you have sold them, which you then pay for twice in refunds and reviews.

Netflix, Spotify, YouTube, Canva and CapCut run no reseller programme. A store selling those at $0.50-$2.50 is reselling pooled or fraudulently created accounts. That is account-sharing fraud at best and handling stolen goods at worst, and it ends in revoked inventory, chargebacks, a terminated PayWay merchant account and liability for the seller rather than the buyer. The same build supports gift cards, game top-ups and real software subscriptions without that exposure.

## Notes

- Product images: `product-images` is a public storage bucket, configured in `supabase/config.toml`.
- Stock payloads are encrypted at rest with `pgp_sym_encrypt`. The key lives in `private.secrets`; only `reveal_order` can decrypt, and it re-checks ownership and paid status on every call.
- `supabase/tests/` is a local harness, not part of the deployed schema.
