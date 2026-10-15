#!/usr/bin/env bash
#
# One-shot setup for a hosted Supabase project.
#
#   1. cp .env.local.example .env.local   # fill it in (never commit this file)
#   2. ./scripts/setup-supabase.sh
#
# Does four things against the linked project: apply migrations, upload the
# Edge Function secrets, deploy the functions, and print the Flutter command.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.local}"

die() { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
ok() { printf '    \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$1"; }

command -v supabase >/dev/null 2>&1 || die "Supabase CLI not found. brew install supabase/tap/supabase"
[ -f "$ENV_FILE" ] || die "$ENV_FILE not found. cp .env.local.example .env.local and fill it in."

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
[ -n "$PROJECT_REF" ] || die "SUPABASE_PROJECT_REF is empty in $ENV_FILE"

step "Checking Supabase CLI authentication"
if ! supabase projects list >/dev/null 2>&1; then
  die "Not logged in. Run: supabase login"
fi
ok "logged in"

step "Linking project $PROJECT_REF"
supabase link --project-ref "$PROJECT_REF" >/dev/null
ok "linked"

step "Applying migrations"
PUSH_ARGS=()
if [ -n "${DATABASE_PASSWORD:-}" ]; then
  PUSH_ARGS+=(--password "$DATABASE_PASSWORD")
else
  warn "DATABASE_PASSWORD empty in $ENV_FILE, the CLI will prompt"
fi
supabase db push "${PUSH_ARGS[@]}"
ok "schema, RLS and RPCs applied"

step "Uploading Edge Function secrets"
REQUIRED_SECRETS=(PAYWAY_ENV PAYWAY_MERCHANT_ID PAYWAY_API_KEY)
missing=()
for key in "${REQUIRED_SECRETS[@]}"; do
  [ -n "${!key:-}" ] || missing+=("$key")
done
if [ ${#missing[@]} -gt 0 ]; then
  warn "skipping secret upload, not set in $ENV_FILE: ${missing[*]}"
  warn "the PayWay functions will answer 503 until these exist"
else
  # Only these are sent: the file also holds DATABASE_PASSWORD and
  # SUPABASE_PROJECT_REF, which must not become function secrets. Supabase
  # injects SUPABASE_URL and the secret key into the runtime itself.
  supabase secrets set \
    "PAYWAY_ENV=${PAYWAY_ENV}" \
    "PAYWAY_MERCHANT_ID=${PAYWAY_MERCHANT_ID}" \
    "PAYWAY_API_KEY=${PAYWAY_API_KEY}" >/dev/null
  ok "PAYWAY_ENV, PAYWAY_MERCHANT_ID, PAYWAY_API_KEY set"
fi

telegram_secrets=()
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && telegram_secrets+=("TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}")
[ -n "${TELEGRAM_WEBHOOK_SECRET:-}" ] && telegram_secrets+=("TELEGRAM_WEBHOOK_SECRET=${TELEGRAM_WEBHOOK_SECRET}")
[ -n "${TELEGRAM_DISPATCH_SECRET:-}" ] && telegram_secrets+=("TELEGRAM_DISPATCH_SECRET=${TELEGRAM_DISPATCH_SECRET}")
if [ ${#telegram_secrets[@]} -gt 0 ]; then
  supabase secrets set "${telegram_secrets[@]}" >/dev/null
  ok "${#telegram_secrets[@]} Telegram secret(s) set"
else
  warn "no Telegram secrets in $ENV_FILE, the bot will stay silent"
fi

step "Deploying Edge Functions"
# The CLI bundles the functions with the edge runtime, which it runs in Docker.
if ! docker info >/dev/null 2>&1; then
  die "Docker must be running to bundle Edge Functions. Start Docker and re-run."
fi
supabase functions deploy \
  payway-init payway-verify payway-callback telegram-webhook telegram-dispatch
ok "all five functions deployed"

step "Register this callback URL with ABA PayWay"
echo "    https://${PROJECT_REF}.supabase.co/functions/v1/payway-callback"
echo "    (PayWay merchant profile -> return_url / callback URL)"

step "Run the Flutter app"
cat <<EOF
    cd app && flutter run -d chrome \\
      --dart-define=SUPABASE_URL=https://${PROJECT_REF}.supabase.co \\
      --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
EOF

printf '\n\033[32mDone.\033[0m\n'
