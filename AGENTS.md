# AGENTS.md

Chanpenh: Khmer-first digital storefront (game top-ups, gift cards) paid by ABA KHQR.
Flutter client + Supabase backend. No app server.

## Layout

- `app/` — the Flutter project root, **not the repo root**. Run all `flutter` / `dart`
  commands from `app/`.
- `supabase/migrations/` — schema, RLS, business-logic RPCs. Applied in filename order.
- `supabase/functions/` — Edge Functions (Deno). `_shared/` is not deployed as a function.
- `supabase/templates/` — email bodies referenced by `[auth.email.template.*]` in
  `config.toml`. Must print `{{ .Token }}`; the app signs in with a six-digit code,
  not a link.
- `supabase/tests/` — standalone Postgres harness, **not part of the deployed schema**.

## Commands

From `app/`:

```bash
flutter analyze                       # baseline is "No issues found!" — keep it clean
dart format lib test                  # format
flutter test                          # all widget/unit tests
flutter test test/storefront_test.dart   # single file
flutter gen-l10n                      # regenerate after editing lib/l10n/*.arb
```

`app/lib/l10n/generated/` is **committed**. After changing an `.arb` file, run
`flutter gen-l10n` and commit the regenerated files too; the build does not do it for you.

Whole local stack, one command (needs Docker + `supabase` CLI):

```bash
./scripts/dev.sh                  # stack up, seed, verify, app in Chrome
./scripts/dev.sh -d macos
./scripts/dev.sh --reset          # wipe and re-seed
./scripts/dev.sh --reload-functions   # after editing Edge Function code
```

Money-logic test harness (needs only Docker; creates a throwaway Postgres 16):

```bash
supabase/tests/run.sh
```

Sandbox verification (runs against a live local stack):

```bash
./scripts/verify-sandbox.sh                  # default checks
./scripts/verify-sandbox.sh --check-payway   # declined + underpaid branches
./scripts/verify-sandbox.sh --check-disabled
```

## Environment: the two-file trap

- `.env.local` — hosted project only. Feeds `supabase secrets set`. **Never read by
  local Edge Functions.** Gitignored.
- `supabase/functions/.env` — what the **local** function runtime reads. Set
  `PAYWAY_*`, `DEV_OTP`, `BAY2GAME_API_KEY`, `SUPPLIER_JOB_SECRET`,
  `STORAGE_PUBLIC_URL` here for local runs.

Putting a credential only in `.env.local` is the classic mistake: the function
answers `*_not_configured` while the key looks present.

### Restart rules (they differ)

| Changed | Do this | Why |
|---|---|---|
| Edge Function **code** | `./scripts/dev.sh --reload-functions` | runtime snapshots functions at boot and reuses the stale isolate |
| Edge Function **env** (`supabase/functions/.env`) | `supabase stop && supabase start` | CLI bakes env into the container at creation; `docker restart` keeps old values |

## Architecture invariants — do not break these

1. **All money logic lives in Postgres.** `create_order` recomputes totals from the
   catalogue; client-side numbers are preview only. Never trust client prices.
2. **The PayWay API key never leaves the server.** It lives in Edge Function secrets;
   the app only ever sees a QR string and a status.
3. **ABA is polled, never believed.** `payway-callback` is unsigned and only identifies
   *which* order to check; settlement reads from `check-transaction` plus an amount check.
4. Stock delivery is one atomic `update ... for update skip locked`; a short pick rolls
   back and moves to the manual queue.
5. `order_events` is append-only (trigger-written, no client grants). Don't add writes.
6. Two refund paths are deliberately separate: the automatic supplier-line refund credits
   the **wallet**; `admin_order_set_refund_pending` → `admin_order_mark_refunded` move no
   money (external reversals). Keep them apart so a refund is never paid twice.

## Supabase

- New schema change = new file in `supabase/migrations/`, named
  `YYYYMMDDHHMMSS_description.sql`. Never edit an applied migration.
- `supabase/bundle/combined.sql` is **generated** by `scripts/build-sql-bundle.sh`
  (paste-into-SQL-editor bundle). Do not hand-edit; regenerate after adding a migration.
- Keep test-harness files in `supabase/tests/`; they are not deployed.
- Edge Functions `payway-callback`, `dev-signin`, `telegram-webhook` run with
  `verify_jwt = false`; the supplier workers need an `Authorization` JWT **and** `x-job-secret`.
- Nothing schedules the workers. `scripts/supplier-worker.sh` is the local loop
  (`dev.sh` starts it); pg_cron is the hosted one (`docs/hosted-deploy.md`).
  Without it a paid auto top-up stays in `delivering` for ever.

## Suppliers

Add a supplier as a single file in `supabase/functions/_shared/suppliers/` implementing
`SupplierAdapter` (`types.ts`). Synced variants are priced **at cost** until staff set a
retail price — unpriced SKUs sell at zero margin, never a loss. Product art is mirrored
into the `product-images` bucket because the supplier CDN sends no CORS header and Flutter
web renders images through `fetch`; browser-visible art needs `STORAGE_PUBLIC_URL`
(`http://127.0.0.1:54321` locally — `SUPABASE_URL` is the unresolvable `kong:8000`).
Store the supplier's own bytes untouched. Do not pad or reshape the mirror: supplier art
is square or portrait, the cards `cover`-crop it, and padded copies shrink the art behind
letterbox bars. The demo products in `supabase/seed/demo.sql` have no art on purpose; the
app draws their name instead (`ProductArtFallback`).

The home spotlight wants a wide image, which the supplier does not have. The `game-banner`
Edge Function resolves key art from IGDB (`IGDB_CLIENT_ID` / `IGDB_CLIENT_SECRET`), mirrors
it to `product-images/banners/`, and writes `products.banner_url`; staff trigger it with
**Find banner** in the admin catalogue, and can paste a URL instead. It is staff-only and
verified inside the function (`is_staff()`), not just by the JWT. A weak name match answers
`no_banner_found` rather than showing the wrong game.

## Config / auth

- Flutter envs: `app/config/dev.json` (local, fixed `DEV_OTP`, nothing emailed) and
  `app/config/prod.json` (hosted, real email OTP). Passed via `--dart-define-from-file`.
- **Avoid prod runs while developing.** The hosted mailer allows 2 emails/hour for the
  whole project; a few runs lock sign-in for everyone until the window rolls over.
- Dev sandbox sign-in is ignored unless `SUPABASE_URL` is loopback (`Env.devAuthEnabled`).

## Docs

- `README.md` — the real design/rationale document. Read it before nontrivial changes.
- `implement.md` — original master spec. `PLAN.md` — gap analysis, milestones, decisions
  taken. Check `PLAN.md` for current state before starting new work.
