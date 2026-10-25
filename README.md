# Chanpenh

Khmer-first digital storefront: game top-ups and gift cards, paid with **ABA KHQR** or **card through Dodo**, delivered instantly.

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
4. **A browser redirect is never proof of payment — on either rail.** Dodo's `return_url` only tells the app where to wait. Settlement comes from a signature-verified `dodo-webhook`, or from `dodo-verify` asking Dodo for the payment and checking amount and currency server-side.

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

### 2b. Card payments (Dodo)

Optional. PayWay is enough for ABA; this adds a card rail for buyers who cannot
scan a KHQR. Dodo is the Merchant of Record, so it handles tax and disputes.

1. Create a **Pay What You Want**, one-time, **USD** product in the Dodo
   dashboard. Set its minimum at or below the cheapest item you sell.
2. Put `DODO_PAYMENTS_API_KEY`, `DODO_PAYMENTS_WEBHOOK_KEY`, `DODO_PRODUCT_ID`
   and `DODO_PAYMENTS_ENVIRONMENT=test_mode` in `supabase/functions/.env` for
   local runs, and in `.env.local` for the hosted project
   (`supabase secrets set --env-file`). The environment defaults to
   `test_mode`; a missing or misspelled value can never charge a live card.
3. Register the webhook in Dodo (**Developer → Webhooks**) for at least
   `payment.succeeded`:

   ```
   https://<project-ref>.supabase.co/functions/v1/dodo-webhook
   ```

   `dodo-webhook` runs with `verify_jwt = false`; it proves itself with the
   Dodo signature instead. It answers `401` to anything unsigned.
4. Switch the option on in the store. It is off by default, because a tile
   that always fails is worse than no tile:

   ```sql
   update public.settings set dodo_enabled = true;
   ```

One product serves the whole catalogue. `dodo-checkout` passes the exact
`orders.total_usd` as the session amount (in cents), so a new SKU needs no Dodo
setup. Coupon discounts are already inside that total; the session disables
Dodo's own discount field so the buyer cannot discount a second time and make
the amount check refuse a legitimate payment.

`STORE_APP_URL` builds the `return_url`. Locally it may be unset: the function
falls back to the request's `Origin` header, which is how the Flutter web dev
server gets back to its own order page.

Refunds are **not** wired to Dodo yet. `admin_order_mark_refunded` is for money
reversed outside the app; a Dodo refund must be issued in the Dodo dashboard,
then recorded there. Do not assume the two reconcile.

Verification without credentials:

```bash
deno test --allow-env supabase/tests/dodo/   # signature, replay, status mapping
```

Test cards and decline scenarios are Dodo's dashboard test mode; the account
also needs the webhook pointed at the local stack (`dodo wh listen` or a
tunnel) if you want the push path exercised rather than the poll.

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

VS Code gets the same setups in `.vscode/launch.json`: *Chanpenh dev* and
*Chanpenh prod*, each for Chrome and for a device. Use dev while building screens —
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

It creates a throwaway Postgres 16, applies the migrations, seeds a catalogue and asserts the things that matter: RLS isolation, the oversell guard, quantity limits, required buyer fields, coupon limits, the wallet ledger, the short-pick rollback, the order event log, the support-ticket guards, and the refund states.

## Stages

`[x]` verified, `[~]` scaffolded and compiling but not yet exercised against live ABA, `[ ]` not started.

| # | Stage | State |
|---|---|---|
| 0 | Schema, RLS, RPCs, atomic stock delivery, wallet ledger | `[x]` |
| 1 | PayWay adapter: purchase hash, check-transaction, callback verify | `[x]` |
| 2 | Flutter shell: Khmer/English i18n, theme, routing, Riverpod state | `[x]` |
| 3 | Catalogue: home, category filter, search, product detail, reviews | `[~]` |
| 3a | Home aligned to `implement.md` §6: prominent search, popular-by-sales, data-driven promotions, how it works, trust and support | `[x]` |
| 4 | Cart + checkout, coupon preview, wallet payment | `[~]` |
| 4a | Buyer fields end to end: shared `RequiredFieldsForm`, per-field error under the field it belongs to, keyboard and length driven by the catalogue's `pattern`, per-field "where do I find this?" help, and the pattern enforced in `create_order` rather than only in the app | `[x]` |
| 5 | **Native KHQR sheet**: render QR, deep-link to ABA Mobile, poll and settle | `[~]` |
| 5a | Manual transfer fallback: buyer asks, staff confirm against the bank, one settlement path | `[x]` |
| 5b | Staff operations at `/admin`: overview, orders, refunds, support | `[x]` |
| 5c | Card payments through Dodo: one Pay What You Want product, hosted session, signed webhook, server-side verify and amount check | `[~]` |
| 6 | Orders: history, detail, reveal codes | `[~]` |
| 7 | Auth: Google, email + password, emailed code fallback, password reset | `[~]` |
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
| 16a | Referral attribution: `apply_referral_code`, optional code at signup | `[x]` |
| 17 | Ops: backups, uptime alerts, fraud velocity rules | `[ ]` |
| 19 | Play Store / App Store submission, Khmer store listing | `[ ]` |

The database row of this table is the part that is genuinely verified: `supabase/tests/run.sh` asserts RLS isolation, the oversell guard, quantity limits, required buyer fields, buyer-field patterns, coupon limits, the wallet ledger, the short-pick rollback, top-up limits, the review guard, the supplier refund path, the append-only order history, the support-ticket guards, `refund_pending -> refunded`, and the manual-transfer guards.

Rows 3a, 4a and 5a mean what they say and no more: `flutter analyze` is clean,
`flutter test` passes, and `flutter build web` compiles. They have not been walked
through against the running stack by hand.

Stage 5 is the one to exercise next: it needs live sandbox credentials, and payment flows are where assumptions go to die.

## Authentication

Three ways in, on one screen (`/login`, and `/register` for the same screen
started on the other tab):

| Method | Where it comes from | Notes |
|---|---|---|
| Google | `signInWithOAuth` | one tap, no mail, no rate limit; button appears only when `/auth/v1/settings` says the provider is on |
| Email + password | `signUp` / `signInWithPassword` | rules are `auth.minimum_password_length` and `auth.password_requirements` in `supabase/config.toml`, mirrored by the hint text in the app |
| Emailed six-digit code | `signInWithOtp` / `verifyOtp` | the fallback; needs a working mailer |

Passwords were added without removing the code path on purpose. Resetting a
password needs an email, and Supabase's built-in mailer allows **2 emails per
hour for the entire project** — not per user — so the code path is worth keeping
even after custom SMTP.

The app asks the project `GET /auth/v1/settings` at runtime and renders the
Google button only when the provider is enabled, so enabling it in the dashboard
needs no app rebuild.

**Every email template must print `{{ .Token }}`.** Supabase's stock templates
print only `{{ .ConfirmationURL }}`, which is fine for a website and useless here:
the app collects six digits, so a link-only mail leaves the code field with
nothing to accept. `supabase/templates/` holds all three, each with the code and
the link.

Registration takes a display name, an optional referral code and a terms
acknowledgement. The name rides in the user metadata because
`private.handle_new_user` reads it when it creates the `public.profiles` row; the
referral code goes to `apply_referral_code`, which enforces the rules server-side
(code must exist, no self-referral, first code wins). No money moves on a
referral yet: the reward is a campaign decision, not a signup side effect.

| Method | Cost | Limit | Notes |
|---|---|---|---|
| Google | free | none | scopes are non-sensitive, so no Google review |
| Email + Resend SMTP | 3k/mo free | generous | configured on the hosted project; see `docs/hosted-deploy.md` |
| Email, built-in | free | **2/hour** | testing only; local stack still uses Mailpit |
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

**Hosted email:** keep *Confirm email* **on** under Authentication → Providers →
Email, otherwise `signUp` returns a session immediately and the registration code
is never sent. Add Resend under Authentication → Emails (host `smtp.resend.com`,
port `465`, user `resend`, password = API key, sender on a verified Resend
domain). The local stack keeps confirmations off and uses Mailpit, so
`supabase/config.toml` deliberately differs from the hosted project here — a
plain `supabase config push` would turn registration confirmation off. See
`docs/hosted-deploy.md` for the Resend setup and DNS records.

Then paste the three templates from `supabase/templates/` into
Authentication → Emails — `magic_link.html` into *Magic Link*, `confirmation.html`
into *Confirm signup*, `recovery.html` into *Reset password*. Supabase's stock
templates print only `{{ .ConfirmationURL }}`: the mail reads "Your sign-in link"
and the app's code field has nothing to accept. Every file in this repo prints
`{{ .Token }}` as well, so the rendered mail carries the code.

Set *Minimum password length* to 8 and the character mix to
lower/upper/digits on the same page, so the hosted rules match
`supabase/config.toml` and the app's hints.

The local stack reads the same files via `[auth.email.template.*]` in
`supabase/config.toml`, so Mailpit on :54324 shows what the hosted mailer will
send. Editing a template body only needs the auth container to re-read the file
(Gotrue template reloading is on); adding or renaming a template *section* needs
`supabase stop && supabase start`, because the CLI bakes the template URL into the
container at creation.

### Enabling Google

The button is not hidden by the app: `AuthCapabilities.google` reads
`external.google` from `GET /auth/v1/settings`, and the button renders only when
that says the provider is on. So a missing button means the provider is off —
check `curl -s $SUPABASE_URL/auth/v1/settings -H "apikey: $KEY" | grep -o '"google":[a-z]*'`
before touching the UI. If that call itself fails, `capabilities()` falls back to
`google: false`, which looks identical.

1. Google Cloud → Auth Platform → create an OAuth client (type: Web application).
2. Authorised JavaScript origins: your site URL and `http://localhost:8080`.
3. Authorised redirect URI:
   `https://<project-ref>.supabase.co/auth/v1/callback`
4. Paste the client ID and secret into Authentication → Providers → Google.
5. Add these redirect URLs under Authentication → URL Configuration:
   - `http://localhost:8080`
   - `chanpenh://auth-callback` (mobile deep link, see `Brand.urlScheme`)

No app rebuild is needed afterwards: the settings call is made at runtime.

For a local run, `[auth.external.google]` in `supabase/config.toml` also has to
be switched on, and its redirect URI is
`http://127.0.0.1:54321/auth/v1/callback` — Google needs that exact string, which
is why a local client is easiest as a second OAuth client rather than reusing the
hosted one:

```bash
export SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=...apps.googleusercontent.com
export SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=...
# flip `enabled = false` to true in [auth.external.google], then:
supabase stop && supabase start
```

`enabled` cannot be driven by `env(...)` like the client id and secret are: a
boolean field given a string is a config parse error (`CliConfigParseError`) and
`supabase start` refuses to boot. Verified the hard way. With the provider on,
`/auth/v1/authorize?provider=google` redirects to Google with the right callback,
which is as far as a local test goes without real credentials.

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

**Nothing calls either worker on a schedule.** A paid auto top-up sits in
`delivering` until `supplier-fulfil` runs, and that is the whole "why is my
order stuck" question. Locally `./scripts/dev.sh` starts
`scripts/supplier-worker.sh`, which posts both workers every 30s:

```bash
./scripts/supplier-worker.sh --once       # one pass, right now
./scripts/supplier-worker.sh --stop       # stop the loop dev.sh started
tail -f .dev/supplier-worker.log          # what it did
```

Each pass places **real** supplier orders and spends **real** supplier balance
while `BAY2GAME_API_KEY` is live. On a hosted project the same two calls belong
in pg_cron — the recipe is in `docs/hosted-deploy.md`.

An `auto_topup` product with no supplier SKU linked to its variants is not
worker-deliverable at all. `deliver_order` hands those lines straight to staff
(`manual_waiting`) instead of parking them as `pending`, because a line no
worker can claim is invisible everywhere else.

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

The mirror stores the supplier's own file, at whatever shape the supplier uses —
240x240 logos, 1250x1250 posters, 16:9 banners — and the app crops it at render
time. The cards are 4:3, so a square logo is `cover`-cropped top and bottom and
fills the tile. That is deliberate: padding the art onto a 4:3 canvas shrank it
behind blurred letterbox bars and read as a smaller, softer tile, so the mirror
keeps the source bytes and lets the card crop.

### Banner art for the spotlight

A card wants a square image; the panel at the top of home does not. Cropped, a
square loses its logo; contained, it leaves dead space. `game-banner` resolves
wide key art instead and writes it to `products.banner_url`.

- Source: IGDB (the game database behind Twitch), which carries the publisher's
  own artwork. Configure `IGDB_CLIENT_ID` + `IGDB_CLIENT_SECRET` from a free
  Twitch application. Unset is not fatal: the function answers
  `igdb_not_configured` and staff can still pass an explicit image URL.
- Match: IGDB search is fuzzy, so the function scores the result against the
  catalogue name and refuses a weak match (`no_banner_found`) rather than
  putting the wrong game on the front page. `matched_name` comes back in the
  response so a person can check it.
- Mirror: the chosen image is copied into `product-images/banners/<slug>` and
  `banner_url` records the public URL. IGDB would allow hotlinking; the mirror
  keeps us independent of their paths and of their CORS policy.
- Trigger: staff press **Find banner** on a product in the admin catalogue
  (blank field = search IGDB, a URL = override). The spotlight uses
  `banner_url` full-bleed when present, and otherwise falls back to the square
  art on a blurred backdrop.

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
- `order_events` is the append-only order history. A trigger on `orders` writes every status transition, and no client grant can insert, change or delete a row, so the history cannot be forged from the app.
- Two refund paths, deliberately separate. An automatic refund of a failed supplier line credits the buyer's **wallet** in `supplier_complete_item`. `admin_order_set_refund_pending` then `admin_order_mark_refunded` record a refund made outside that path, such as an ABA reversal, and neither moves money — which is what stops one refund being paid twice.
- Stock payloads are encrypted at rest with `pgp_sym_encrypt`. The key lives in `private.secrets`; only `reveal_order` can decrypt, and it re-checks ownership and paid status on every call.
- `supabase/tests/` is a local harness, not part of the deployed schema.

## Storefront claims

The home page follows the pattern Cambodian buyers already know from SEA Gamer Mall
and the local shops: a search field at the top, then a popular grid, then
promotions, then how it works, then trust. Three rules keep it honest, and they
are the reason a section can be empty:

| Section | Source | When there is nothing |
|---|---|---|
| Popular games | `products.sold_count`, incremented on delivery | Falls back to the staff-curated `is_featured` list, and the heading changes from **Popular games** to **Popular** so the label matches the data |
| Promotions | a variant whose `compare_at_price_usd` beats its live price | The section is omitted. There is no banner the database cannot back up |
| Trust and support | `support_telegram` / `support_email` from `public_settings` | No contact button is drawn, rather than a dead one |

Nothing on the page is a fixed number: no countdown timer, no invented stock
counter, no discount the catalogue does not carry. `test/storefront_test.dart`
holds that: the discount predicate rejects a compare price that is not a
reduction, `refund_pending` is asserted not to read as `pending`, and both
contact buttons are asserted not to overflow at 320px.

Two claims were **removed** from the copy because the store cannot support them:
"24/7" delivery and "24/7" support. Reinstating either is a business decision,
not a translation one.

Internal errors are rendered only in debug builds. A PostgREST message can name
tables and policies, and `implement.md` §7 forbids showing that to a customer.

## Buyer fields

A product that needs an account id declares it on `products.requires_fields`:

```json
[{"key":"userid","label_en":"Game ID","placeholder":"123456789",
  "pattern":"^[0-9]{6,12}$","help_en":"...","guide_image_url":"..."}]
```

`key` must match the supplier's own parameter name — Bay2Game's `userid` and
`serverid` — or the adapter cannot map it. Labels are free text.

Three rules, and they exist because the wrong id is a top-up delivered to a
stranger:

| Rule | Where |
|---|---|
| A required field must be present **and** match its `pattern`, and be at most 64 characters | `create_order`, before the stock check. Raises `missing_fields` / `invalid_fields` with the offending keys in `detail` |
| The buyer is told the same thing before paying | `core/field_validation.dart`, used by the shared `RequiredFieldsForm` on both the product page and checkout |
| An unusable `pattern` is treated as no pattern | Both places. A pattern is data, so it can be malformed, and `~`/`RegExp` raise on one — that would make a whole game unsellable over a typo in a validation string |

Until this was added, the pattern was enforced in the app **only**. A crafted
request — or simply an older build of the app — sent `userid = 'abc'`, which the
RPC accepted. The buyer paid, the supplier rejected the id, and the automatic
path refunded the wallet: the store found out about a bad id after taking money
for it.

Help text resolves in order of who knows best: the catalogue's own `help_km` /
`help_en`, then the copy for a field key the app recognises (`userid`,
`serverid` and their supplier aliases), then a general answer. **No screenshots
ship with the app**, and none are seeded: a screenshot of a game's profile
screen is a claim about that game's current UI, and there is no way to verify one
from here. `guide_image_url` is rendered when the catalogue carries one.

## Manual transfer fallback

PayWay is the path to prefer. It exists only if the project has PayWay
credentials, and a buyer whose bank app will not open the deeplink is stuck on a
pending order with nothing to do. So the order page also offers a transfer to the
store's ABA account, which a human confirms.

Three things make it safe to have a second way in:

1. **One settlement path.** `admin_confirm_manual_payment` calls the same
   `mark_order_paid` the PayWay callback calls, with provider `manual` (that enum
   value existed, unused). Stock allocation, coupon redemption, the wallet
   top-up branch and the supplier queue behave exactly as after a PayWay
   settlement. A second settlement implementation is how the two drift and money
   moves twice.
2. **The amount is stated, not assumed.** PayWay asks ABA what was paid and
   refuses to deliver on a shortfall; a human does the same. Staff type what the
   bank app shows, and the RPC refuses anything below `orders.total_usd`
   (`manual_underpaid`). "The buyer said they paid" is not an amount, and a
   screenshot is never evidence.
3. **A reference settles one order.** `payments` is unique on
   `(provider, provider_ref)`. Confirming a second order with a reference already
   on a first would silently re-point that row while still settling the second —
   one transfer paying for two orders. The RPC refuses it
   (`manual_reference_used`).

| Step | Effect |
|---|---|
| Buyer taps "I have paid" | `request_manual_payment`: own pending order only, once per order, 3 per hour per user. No money moves. Extends `expires_at` by `manual_grace_minutes` (default 1440) — without that, housekeeping cancels the order at 15 minutes while the transfer is still in flight |
| Staff confirm in `/admin` | `admin_confirm_manual_payment`: staff-only, pending and unexpired, amount ≥ total, reference required and unused |
| Staff dismiss | `admin_clear_manual_payment_request`: clears the flag with a required reason. Nothing is refunded — the order simply goes back to being unpaid |
| Double click | A no-op: `mark_order_paid` only moves money on `pending` |

An **expired** order is not settled by hand (`order_expired`). The money is real,
so it goes down the external-refund path
(`admin_order_set_refund_pending` → `admin_order_mark_refunded`) where a person
handles it, rather than being quietly accepted into an order housekeeping has
already cancelled.

`staff_manual_payments` is a **`security_invoker`** view. That is not decoration:
a plain view belongs to its owner and reads the base table as that owner, which
would hand every customer's order to any signed-in caller. With
`security_invoker`, the policies on `orders` apply to whoever queries it —
harness section 70 pins that a customer sees `0` rows while staff see `1`.

The panel renders only when settings carry both `khqr_account_id` and
`khqr_merchant_name`; a store that has not filled them in shows nothing rather
than an instruction the buyer cannot act on. The demo seed's `chanpenh@aclb` / `CHANPENH`
are placeholders and must be replaced before taking real money.

## Card payments (Dodo)

Dodo is the second rail, not a replacement. Same order, same `mark_order_paid`,
same delivery: only the way money arrives differs.

| Function | Who calls it | What it decides |
|---|---|---|
| `dodo-checkout` | the app, signed in | Creates a hosted session for `orders.total_usd`, records a pending attempt |
| `dodo-verify` | the app, while the sheet is open | Asks Dodo for the session/payment, checks amount and currency, settles |
| `dodo-webhook` | Dodo | Verifies the signature on the raw body, settles on `payment.succeeded` |

Three choices are deliberate:

1. **One Pay What You Want product.** The catalogue already lives in Postgres;
   mirroring every variant into Dodo would create a second catalogue that drifts.
   The session carries the exact total in cents instead.
2. **The app polls, the webhook decides.** The poll makes the sheet close as
   soon as the payment lands and recovers a missed webhook. The webhook is the
   primary signal, and both call the same settlement helper so they cannot
   disagree.
3. **Amount and currency are checked server-side.** `total_amount` must cover
   the order in USD. Dodo may add tax on top (the check is `>=`); it can never be
   below. An underpaid event is acknowledged and refused, not retried for ever.

The enum value `dodo` was added in its own migration: Postgres refuses to use a
new enum value in the transaction that adds it. `provider_session_id` carries
the `cks_...` id the app polls; `provider_ref` carries the `pay_...` id that
settles, so the existing `(provider, provider_ref)` unique index still makes
settlement idempotent.

## Staff operations (`/admin`)

A hub and four screens, all inside the same app and behind one gate
(`AdminGate`): orders, refunds, support, and M4's transfer queue. The gate is a
convenience — a non-staff session never reaches the queries, and every RPC behind
it re-checks `is_staff()` in the database, so a route reached by hand yields
nothing.

### The overview does not estimate

`admin_overview()` counts rows and sums payments, and the migration says what it
will not do. Three rules are worth stating because each one is a way to double
count or rewrite history:

- **Received is summed from `payments`, not from `orders`.** A wallet top-up and
  the purchase it later pays for both carry an order total; summing orders
  counts one barrel of money twice.
- **Wallet spend is separate, and it is not new money.** The cash arrived when
  the balance was topped up.
- **Refunds are reported beside received, never netted off it.** A refunded
  payment still arrived; subtracting it from the window it arrived in changes
  what last week's figure says.

There is no growth rate, no "active users" and no conversion figure, because each
would have to be invented. "Today" is a **Phnom Penh** day: `now()` is UTC, so the
boundary is computed in the store's timezone and the timezone is shown on screen
next to the numbers.

### Refunds stay two steps

`refund_pending` says staff agreed; `refunded` says the money went back.
`/admin/refunds` and the order screen only ever call `admin_order_mark_refunded`,
which **moves no money** — the reversal happens in the bank, where a person does
it. The screen says so out loud rather than leaving staff to guess.

### One function had to be fixed

`admin_support_set_status` coalesces its parameters so a caller can update one
field, but it wrote `resolved_at` unconditionally: a note-only call passed
`p_status = null`, the `case` fell through to `else null`, and the time a ticket
was resolved was erased. `20261015001200_support_note_fix.sql` re-creates it so
`resolved_at` only moves when a status is actually set. Harness §75 pins it.

### Known gap: dead staff policies

`audit_log`, `suppliers`, `supplier_skus`, `settings`, `coupons` and
`coupon_redemptions` have staff policies but **no grant to `authenticated`**, so
the policies protect a table nobody can read. Products, variants and categories
have write policies but no write grants. M5a needed none of these; fixing them
belongs with the screens that will use them (catalogue and settings editing).
Until then, edit those tables with SQL.
