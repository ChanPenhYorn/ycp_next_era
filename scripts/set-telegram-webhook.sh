#!/usr/bin/env bash
#
# Points Telegram at the deployed webhook, and prints what Telegram thinks.
#
#   ./scripts/set-telegram-webhook.sh
#
# Set TELEGRAM_WEBHOOK_SECRET in .env.local first. Without it the endpoint is
# open to anyone who knows the URL, and they could forge updates.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.local}"

die() { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

[ -f "$ENV_FILE" ] || die "$ENV_FILE not found."

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || die "TELEGRAM_BOT_TOKEN is empty in $ENV_FILE"
[ -n "${SUPABASE_PROJECT_REF:-}" ] || die "SUPABASE_PROJECT_REF is empty in $ENV_FILE"

if [ -z "${TELEGRAM_WEBHOOK_SECRET:-}" ]; then
  die "TELEGRAM_WEBHOOK_SECRET is empty.
Generate one, add it to $ENV_FILE, then upload it as a function secret:
  openssl rand -hex 24
  supabase secrets set TELEGRAM_WEBHOOK_SECRET=<value>"
fi

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
URL="https://${SUPABASE_PROJECT_REF}.supabase.co/functions/v1/telegram-webhook"

step "Registering $URL"
curl -s -X POST "$API/setWebhook" \
  -H "Content-Type: application/json" \
  -d "$(printf '{"url":"%s","secret_token":"%s","allowed_updates":["message","callback_query"]}' \
        "$URL" "$TELEGRAM_WEBHOOK_SECRET")" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print("    ok" if d.get("ok") else "    FAILED: "+str(d.get("description")))'

step "Telegram's current view"
curl -s "$API/getWebhookInfo" | python3 -m json.tool

step "Bot identity"
curl -s "$API/getMe" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin)["result"]; print(f"    {d[\"first_name\"]} @{d[\"username\"]}")'

printf '\n'
