# Hosted deploy plan

Status: **not started.** Written so a person or agent can pick it up later.
Nothing here has been run against the hosted project yet.

## Context

| Flavor | Config | Backend | Auth |
|---|---|---|---|
| dev | `app/config/dev.json` | local stack `127.0.0.1:54321` | fixed `DEV_OTP`, nothing emailed |
| prod | `app/config/prod.json` | hosted Supabase | real email OTP |

"Deploy" means prod.

### Current hosted project: `ycp_next_era`

- Ref: `ozelquxztpqpjikhgnxd` (region `ap-northeast-1`, Postgres 17). Org `iwjbwmosishxazcefvpq`.
- `supabase link` was run against it. That only writes local `supabase/.temp`.
- **Drift:** schema exists but migration history is empty. `supabase db push --linked`
  fails at `20261015000100_init_schema.sql` with `type "product_kind" already exists`.
- **Data present:** 1 profile, 4 products, 0 orders, 0 payments.
- `supabase db diff --linked` timed out. Exact drift unknown.
- No schema changes were made by the failed push. Verify before relying on it.

### Domain and tunnel

- Domain `chanpenh.store` is on Cloudflare DNS. `https://chanpenh.store/` returns 200.
  Backend behind it is **unknown**.
- Named tunnel `ycp-dev` (id `1c936dc2-0649-45a4-8ec0-be81298e98b2`) routes
  `dev-api.chanpenh.store` → `http://127.0.0.1:54321`. Dev only.
- Credentials: `~/.cloudflared/*.json`. Never commit.
- The tunnel and local stack run on the developer's Mac. Closing the Mac stops both.

### Telegram

- Bot `@ycp_store_bot` (id `8621492310`). Token lives in `supabase/functions/.env`
  (local) and `.env.local` (hosted secrets source). Never commit.
- **One bot token = one webhook URL.** Dev and prod cannot both receive updates.
  Current webhook: `https://dev-api.chanpenh.store/functions/v1/telegram-webhook`.
- Menu button: `Dashboard` → `https://chanpenh.store/`.
- Command menu set (EN + KM): `orders`, `order`, `wallet`, `help`, `unlink`.
- Bot name: `Chanpenh Store`. Profile photo: set manually in BotFather (`/setuserpic`).

## Decision needed

Pick one before any prod write:

1. **Fresh project (recommended).** Create a new Supabase project. Push the 13
   migrations into an empty DB. Leave `ycp_next_era` alone.
2. **Reset `ycp_next_era`.** Wipe schema and data (4 products, 1 profile), then push.
   Destructive. Needs explicit confirmation.
3. **Adopt existing schema.** Diff remote vs local. If they match, run
   `supabase migration repair --status applied <version>` for each. Only if drift is small.

## Steps (after the decision)

Each prod write is a separate confirmed step.

1. **Create project** (fresh option): org `iwjbwmosishxazcefvpq`, region
   `ap-southeast-1`. Set DB password. Record ref here.
2. **Link:** `supabase link --project-ref <ref>`.
3. **Dry run:** `supabase db push --linked --dry-run`. Expect 13 migrations.
4. **Push schema:** `supabase db push --linked`.
5. **Auth config and email templates:** `supabase config push`. Templates live in
   `supabase/templates/`; they must print `{{ .Token }}` (six-digit code, not a link).
6. **Secrets (prod only):** `supabase secrets set --env-file <tmp file>` with only:
   `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`, `TELEGRAM_DISPATCH_SECRET`,
   `PAYWAY_*`, `BAY2GAME_API_KEY`, `SUPPLIER_JOB_SECRET`, `STORE_APP_URL`.
   **Never** `DEV_OTP`. Delete the temp file afterwards.
7. **Deploy functions:** `telegram-webhook`, `telegram-dispatch`, `payway-init`,
   `payway-verify`, `payway-callback`, `supplier-sync`, `supplier-fulfil`.
   **Skip** `dev-signin`.
8. **Settings and catalog:** prod settings row (site name, KHQR account, `telegram_bot_username`,
   `support_telegram_chat_id`). Catalog created by staff, not `seed/demo.sql`.
9. **Smoke:** `./scripts/verify-sandbox.sh` against hosted is **not** applicable (it assumes
   local). Check by hand: sign in with real email OTP, create order, Telegram `/help`.
10. **Webhook switch:**
    `setWebhook` to `https://<ref>.supabase.co/functions/v1/telegram-webhook`
    with `secret_token=TELEGRAM_WEBHOOK_SECRET`. Then the dev tunnel stops receiving bot traffic.
11. **App:** `cd app && flutter build web --dart-define-from-file=config/prod.json`.
    Deploy `app/build/web` to Cloudflare Pages on `chanpenh.store`.
12. **Menu button and `STORE_APP_URL`:** already `https://chanpenh.store/`. Re-check after step 11.
13. **Keep** `dev-api` tunnel for local development only.

## Rules that apply

From `AGENTS.md`:
- Never edit an applied migration. New schema = new file in `supabase/migrations/`.
- Avoid prod runs while developing. Hosted mailer allows 2 emails/hour for the whole project.
- Edge Function env changes need `supabase stop && supabase start` locally.
- `supabase/bundle/combined.sql` is generated. Do not hand-edit.

## Open questions

- What serves `chanpenh.store` today? If it calls local Supabase, it breaks when the Mac is off.
- PayWay: sandbox keys or live? Keep `PAYWAY_ENV` on sandbox until live is approved.
- Who owns the Telegram bot token after rotation? (Token was pasted in chat; rotate via BotFather `/revoke`.)
