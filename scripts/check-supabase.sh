#!/usr/bin/env bash
#
# Post-setup verification. Reads .env.local, touches nothing, prints a report.
#
#   ./scripts/check-supabase.sh
#
# Safe to run any time: every call uses the publishable key, which is protected
# by the RLS policies in supabase/migrations/20261015000200_rls.sql.
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.local}"

pass() { printf '  \033[32m✓\033[0m %-34s %s\n' "$1" "$2"; }
fail() { printf '  \033[31m✗\033[0m %-34s %s\n' "$1" "$2"; }
info() { printf '  \033[36m·\033[0m %-34s %s\n' "$1" "$2"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE. cp .env.local.example .env.local"; exit 1; }
set -a; . "$ENV_FILE"; set +a

URL="${SUPABASE_URL:-}"
KEY="${SUPABASE_PUBLISHABLE_KEY:-}"
REF="${SUPABASE_PROJECT_REF:-}"

[ -n "$URL" ] || { echo "SUPABASE_URL is empty in $ENV_FILE"; exit 1; }
[ -n "$KEY" ] || { echo "SUPABASE_PUBLISHABLE_KEY is empty in $ENV_FILE"; exit 1; }

# Returns the HTTP status for a REST path.
rest_status() {
  curl -s -o /dev/null -w '%{http_code}' \
    "$URL/rest/v1/$1" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
}

head_ "Project"
info "url" "$URL"
info "ref" "${REF:-<not set>}"

head_ "Database schema and RLS"
for table in products product_variants categories variant_stock public_settings; do
  status="$(rest_status "$table?select=*&limit=1")"
  case "$status" in
    200|206) pass "$table" "readable ($status)" ;;
    401|403) fail "$table" "denied ($status) - migrations not applied?" ;;
    404)     fail "$table" "missing ($status) - migrations not applied?" ;;
    *)       fail "$table" "unexpected $status" ;;
  esac
done

head_ "Protected tables must refuse an anonymous read"
# `payments` has no anon policy on purpose: proving it fails here is the point.
if [ "$(rest_status 'payments?select=id&limit=1')" = "200" ]; then
  fail "payments" "READABLE ANONYMOUSLY - RLS is wrong, stop and fix"
else
  pass "payments" "denied to anon, as intended"
fi

head_ "Edge Functions"
probe() {
  curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/functions/v1/$1" \
    -H "Content-Type: application/json" -d '{}'
}

# verify_jwt = true -> 401 without a JWT. That still proves it deployed.
code="$(probe payway-init)"
case "$code" in
  401) pass "payway-init" "deployed, JWT required" ;;
  404) fail "payway-init" "not deployed (404)" ;;
  *)   fail "payway-init" "unexpected $code" ;;
esac

code="$(probe payway-verify)"
case "$code" in
  401) pass "payway-verify" "deployed, JWT required" ;;
  404) fail "payway-verify" "not deployed (404)" ;;
  *)   fail "payway-verify" "unexpected $code" ;;
esac

# verify_jwt = false, so anything other than 401/404 means it is live and
# reachable by ABA the way the callback needs to be.
code="$(probe payway-callback)"
case "$code" in
  401) fail "payway-callback" "JWT still required - set verify_jwt = false" ;;
  404) fail "payway-callback" "not deployed (404)" ;;
  400) pass "payway-callback" "deployed and publicly reachable" ;;
  *)   info "payway-callback" "reachable, returned $code" ;;
esac

head_ "PayWay configuration"
if [ -z "${PAYWAY_MERCHANT_ID:-}" ] || [ -z "${PAYWAY_API_KEY:-}" ]; then
  info "credentials" "not in .env.local yet, so no payment can be taken"
else
  info "credentials" "present locally - confirm with a sandbox payment"
fi
echo "  callback URL to whitelist with ABA:"
echo "    $URL/functions/v1/payway-callback"

printf '\n'
