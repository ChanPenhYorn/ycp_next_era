#!/usr/bin/env bash
#
# Runs the app against the local Supabase stack with the sandbox sign-in code.
#
#   supabase start
#   ./scripts/run-sandbox.sh -d chrome
#
# Nothing is emailed: dev-signin trades the fixed code for a real session, so
# the hosted mailer's 2-per-hour budget and its "Confirm your email address"
# template stay out of the way while testing.
#
# The defines come from app/config/dev.json, the same file the VS Code dev
# configs use, so there is one place to change them. This script only checks
# that the file still matches the stack that is actually running.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/app/config/dev.json"

die() { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

command -v supabase >/dev/null 2>&1 || die "The supabase CLI is not on PATH."
[ -f "$CONFIG" ] || die "$CONFIG is missing."

read_config() {
  # -c, not a heredoc: a heredoc would take over stdin.
  python3 -c '
import json, sys
with open(sys.argv[1]) as handle:
    print(json.load(handle).get(sys.argv[2], ""))
' "$CONFIG" "$1"
}

read_status() {
  python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
except ValueError:
    raise SystemExit(0)
if data.get("_tag") == "Error":
    raise SystemExit(0)
for name in sys.argv[1:]:
    if data.get(name):
        print(data[name])
        break
' "$@"
}

STATUS="$(cd "$ROOT" && supabase status -o json 2>/dev/null || true)"
LIVE_URL="$(printf '%s' "$STATUS" | read_status API_URL api_url)"
# PUBLISHABLE_KEY first: it is the name the app and the dashboard use now.
LIVE_KEY="$(printf '%s' "$STATUS" | read_status PUBLISHABLE_KEY ANON_KEY)"

[ -n "$LIVE_URL" ] || die "No local stack is running. Start one with: supabase start"

URL="$(read_config SUPABASE_URL)"
KEY="$(read_config SUPABASE_PUBLISHABLE_KEY)"
OTP="$(read_config DEV_OTP)"

[ -n "$URL" ] || die "SUPABASE_URL is empty in $CONFIG"
[ -n "$KEY" ] || die "SUPABASE_PUBLISHABLE_KEY is empty in $CONFIG"
[ -n "$OTP" ] || die "DEV_OTP is empty in $CONFIG. Without it the app emails a real
code instead, which the hosted mailer answers with a rate limit."

# App-side guardrails, checked here too so the failure is one clear line instead
# of a login screen that quietly sent an email.
case "$URL" in
  http://127.0.0.1:*|http://localhost:*|http://\[::1\]:*) ;;
  *) die "$CONFIG points at $URL. Only a loopback URL enables the sandbox code." ;;
esac

if [ "$URL" != "$LIVE_URL" ]; then
  die "$CONFIG says $URL but the running stack is $LIVE_URL."
fi

if [ "$KEY" != "$LIVE_KEY" ]; then
  die "$CONFIG holds a key the running stack does not recognise.
Set SUPABASE_PUBLISHABLE_KEY in $CONFIG to:
  $LIVE_KEY"
fi

[ -f "$ROOT/supabase/functions/.env" ] || die \
  "supabase/functions/.env is missing. Without DEV_OTP in it, dev-signin answers 404.
Create it with: echo DEV_OTP=$OTP > supabase/functions/.env"

printf '\n\033[1m==> Sandbox against %s\033[0m\n' "$URL"
printf '\033[1m==> Sign-in code %s, no email is sent\033[0m\n' "$OTP"

# An empty catalogue renders a blank home screen and reads like a broken query.
# Say which it is, without blocking the run.
EMPTY="$(curl -s -G "$URL/rest/v1/products" --data-urlencode 'select=id' \
  --data-urlencode 'limit=1' -H "apikey: $KEY" -H "Authorization: Bearer $KEY" 2>/dev/null || true)"
case "$EMPTY" in
  '[]')
    printf '\033[33m==> No products in this database. Seed it with: supabase db reset\033[0m\n'
    ;;
esac

cd "$ROOT/app"
exec flutter run --dart-define-from-file=config/dev.json "$@"
