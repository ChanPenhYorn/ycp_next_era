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
   Keep *Confirm email* on and configure Resend SMTP with the snippet below. A plain
   push from `supabase/config.toml` sets `enable_confirmations = false` (the local
   default), which silently skips the registration code.
6. **Secrets (prod only):** `supabase secrets set --env-file <tmp file>` with only:
   `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`, `TELEGRAM_DISPATCH_SECRET`,
   `PAYWAY_*`, `BAY2GAME_API_KEY`, `SUPPLIER_JOB_SECRET`, `STORE_APP_URL`,
   `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET`.
   **Never** `DEV_OTP`. Delete the temp file afterwards.
7. **Deploy functions:** `telegram-webhook`, `telegram-dispatch`, `payway-init`,
   `payway-verify`, `payway-callback`, `supplier-sync`, `supplier-fulfil`,
   `game-banner`.
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

## Email OTP via Resend

Hosted project uses Resend SMTP for sign-in codes, signup confirmation and
password resets. `chanpenh.store` is verified in Resend, and Resend reports the
confirmation mail as **delivered** to a real Gmail recipient.

DNS records live in Cloudflare, DNS-only (grey cloud):

| Type | Name | Value |
|---|---|---|
| TXT | `resend._domainkey` | DKIM public key from Resend |
| MX | `send` | `feedback-smtp.us-east-1.amazonses.com` priority 10 |
| TXT | `send` | `v=spf1 include:amazonses.com ~all` |
| CNAME | `rsend` | `send.forge.rmta.net` |

The root MX stays with Zoho; these records only cover the `send`/`rsend`
subdomains. If the domain is ever re-added, Resend issues new values — copy them
from <https://resend.com/domains>, do not reuse these.

SMTP settings for Supabase Auth (Authentication → Emails → SMTP):

```toml
[auth.email.smtp]
enabled = true
host = "smtp.resend.com"
port = 465
user = "resend"
pass = "env(SUPABASE_AUTH_SMTP_PASS)"   # Resend API key, re_...
admin_email = "noreply@chanpenh.store" # must be on the verified domain
sender_name = "Chanpenh"
```

The hosted project is configured through `supabase config push` with the SMTP
password stored as a secret. `SUPABASE_AUTH_SMTP_PASS` is only needed in the
environment when pushing; do not commit it. Live sender: `noreply@chanpenh.store`.

Proof run against the hosted project: `POST /auth/v1/signup` returned
`confirmation_sent_at`, Resend listed the mail as delivered, and the six-digit
code from that mail exchanged for a session at `POST /auth/v1/verify`. The test
user was deleted afterwards.

Local development does **not** use Resend: `supabase/config.toml` declares no SMTP
block, so the local auth container keeps writing to Mailpit on :54324.

## Schedule the workers (do not skip this)

`supplier-fulfil` and `telegram-dispatch` are the only things that turn a paid
auto top-up into a delivered one, and neither is called by anything on a timer.
Without a schedule an order pays, flips to `delivering`, and stays there for
ever while the buyer waits. Locally `scripts/dev.sh` starts
`scripts/supplier-worker.sh` for you; on the hosted project the same two calls
belong in pg_cron.

Put the credentials in Vault first, so the schedule never carries them in
plaintext. Run this once in the SQL editor (substitute `<ref>`):

```sql
select vault.create_secret('<anon JWT>',          'worker_jwt',            'scheduled worker auth');
select vault.create_secret('<SUPPLIER_JOB_SECRET>',    'supplier_job_secret',   'supplier-fulfil job secret');
select vault.create_secret('<TELEGRAM_DISPATCH_SECRET>','dispatch_secret',       'telegram-dispatch secret');

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule('ycp-supplier-fulfil', '* * * * *', $job$
  select net.http_post(
    url := 'https://<ref>.supabase.co/functions/v1/supplier-fulfil',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'worker_jwt'),
      'x-job-secret',  (select decrypted_secret from vault.decrypted_secrets where name = 'supplier_job_secret')
    ),
    body := '{"limit": 20}'::jsonb
  );
$job$);

select cron.schedule('ycp-telegram-dispatch', '* * * * *', $job$
  select net.http_post(
    url := 'https://<ref>.supabase.co/functions/v1/telegram-dispatch',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'worker_jwt'),
      'x-dispatch-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'dispatch_secret')
    ),
    body := '{}'::jsonb
  );
$job$);
```

Confirm it is really running, not just scheduled:

```sql
select jobname, schedule, active from cron.job;
select status_code, content from net._http_response order by created desc limit 5;
```

A missing or expired `worker_jwt` shows up as `401` there and as `unauthorized`
in the function logs — that is the failure to watch for, because the orders stay
silently in `delivering`.

`expire_stale_orders()` and `refresh_all_product_ratings()` are already
scheduled by migration `20261015000400_wallet_cron_admin.sql`, so pg_cron is
available on any project that has run the migrations.

## Rules that apply

From `AGENTS.md`:
- Never edit an applied migration. New schema = new file in `supabase/migrations/`.
- Avoid prod runs while developing. Hosted auth now uses Resend SMTP (3k/month), but test with the dev stack's Mailpit where possible.
- Edge Function env changes need `supabase stop && supabase start` locally.
- `supabase/bundle/combined.sql` is generated. Do not hand-edit.

## Open questions

- What serves `chanpenh.store` today? If it calls local Supabase, it breaks when the Mac is off.
- PayWay: sandbox keys or live? Keep `PAYWAY_ENV` on sandbox until live is approved.
- Who owns the Telegram bot token after rotation? (Token was pasted in chat; rotate via BotFather `/revoke`.)
