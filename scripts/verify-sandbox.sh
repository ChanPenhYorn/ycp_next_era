#!/usr/bin/env bash
#
# Verifies sandbox sign-in against the running local stack.
#
#   supabase start
#   ./scripts/verify-sandbox.sh
#
# Checks what the app actually depends on: the fixed code is refused when wrong,
# it produces a real session when right, that session is scoped by RLS, and
# repeat sign-ins keep working. Exits non-zero if anything fails, so it can run
# in CI next to supabase/tests/run.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/app/config/dev.json"
WORK="$(mktemp -d)"
# Restored by cleanup when --check-disabled had to edit it.
ENV_FILE="$ROOT/supabase/functions/.env"
RESTORING=""

cleanup() {
  if [ -n "$RESTORING" ] && [ -f "$WORK/functions.env" ]; then
    cp "$WORK/functions.env" "$ENV_FILE"
    restart_stack
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
expect() { # expect <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 — expected [$2], got [$3]"; fi
}

# The edge runtime mounts supabase/functions live, but reads .env once, when the
# CLI builds the container: `docker inspect` shows DEV_OTP baked into the
# container environment. A `docker restart` therefore changes nothing, and
# `supabase start` on a running stack is a no-op. Only a stop/start re-reads it.
restart_stack() {
  (cd "$ROOT" && supabase stop >/dev/null 2>&1; supabase start >/dev/null 2>&1)
}

# A restarting runtime answers 502, and curl exits 0 for that, so wait for a
# real status from the function itself instead of trusting the first response.
wait_for_runtime() {
  local attempt code
  for attempt in $(seq 1 90); do
    code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$ENDPOINT" \
      -H "apikey: $KEY" -H 'Content-Type: application/json' \
      -d '{"email":"probe@example.com","code":"000000"}')"
    case "$code" in
      2*|4*) return 0 ;;
    esac
    sleep 1
  done
  return 1
}

json() { python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    print(""); raise SystemExit(0)
value = data
for key in sys.argv[1].split("."):
    if isinstance(value, list) and key.isdigit() and int(key) < len(value):
        value = value[int(key)]
    elif isinstance(value, dict) and key in value:
        value = value[key]
    else:
        print(""); raise SystemExit(0)
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
' "$1"; }

# --- inputs ---------------------------------------------------------------
URL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["SUPABASE_URL"])' "$CONFIG")"
OTP="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["DEV_OTP"])' "$CONFIG")"

STATUS="$(cd "$ROOT" && supabase status -o json 2>/dev/null || true)"
KEY="$(printf '%s' "$STATUS" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
except ValueError:
    raise SystemExit(0)
print(data.get("PUBLISHABLE_KEY") or data.get("ANON_KEY") or "")
')"

[ -n "$URL" ] && [ -n "$OTP" ] && [ -n "$KEY" ] || {
  printf '\n\033[31merror:\033[0m Need a running stack and %s. Try: supabase start\n' "$CONFIG" >&2
  exit 1
}

EMAIL="sandbox-$(date +%s)@example.com"
AUTH_HEADERS=(-H "apikey: $KEY" -H 'Content-Type: application/json')
ENDPOINT="$URL/functions/v1/dev-signin"

printf '\n\033[1mSandbox sign-in against %s\033[0m\n' "$URL"
printf 'code %s, probe address %s\n\n' "$OTP" "$EMAIL"

# --- the function refuses misuse ------------------------------------------
printf 'guardrails\n'

CODE="$(curl -s -o "$WORK/get.json" -w '%{http_code}' "$ENDPOINT" -H "apikey: $KEY")"
expect 'GET is rejected' 405 "$CODE"

CODE="$(curl -s -o "$WORK/empty.json" -w '%{http_code}' -X POST "$ENDPOINT" "${AUTH_HEADERS[@]}" -d '{}')"
expect 'missing email is rejected' 400 "$CODE"

CODE="$(curl -s -o "$WORK/wrong.json" -w '%{http_code}' -X POST "$ENDPOINT" "${AUTH_HEADERS[@]}" \
  -d "{\"email\":\"$EMAIL\",\"code\":\"000000\"}")"
expect 'wrong code is rejected' 401 "$CODE"
expect 'wrong code names the reason' invalid_code "$(json error < "$WORK/wrong.json")"

# A function with verify_jwt = false is reachable without an apikey, so the code
# itself is the only gate. Worth asserting rather than assuming: it is why
# DEV_OTP must never be set on a hosted project.
CODE="$(curl -s -o "$WORK/noauth.json" -w '%{http_code}' -X POST "$ENDPOINT" \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"code\":\"000000\"}")"
expect 'the code gate applies even without an apikey' 401 "$CODE"

# --- the code works -------------------------------------------------------
printf '\nsign-in\n'

CODE="$(curl -s -o "$WORK/signin.json" -w '%{http_code}' -X POST "$ENDPOINT" "${AUTH_HEADERS[@]}" \
  -d "{\"email\":\"$EMAIL\",\"code\":\"$OTP\"}")"
expect 'the sandbox code is accepted' 200 "$CODE"

TOKEN_HASH="$(json token_hash < "$WORK/signin.json")"
if [ -n "$TOKEN_HASH" ] && [ -z "${TOKEN_HASH//[0-9a-f]/}" ]; then
  ok "a token hash comes back (${#TOKEN_HASH} hex chars)"
else
  bad "no usable token hash: [$TOKEN_HASH]"
fi

CODE="$(curl -s -o "$WORK/session.json" -w '%{http_code}' -X POST "$URL/auth/v1/verify" "${AUTH_HEADERS[@]}" \
  -d "{\"type\":\"magiclink\",\"token_hash\":\"$TOKEN_HASH\"}")"
expect 'the hash exchanges for a session' 200 "$CODE"

ACCESS="$(json access_token < "$WORK/session.json")"
USER_ID="$(json user.id < "$WORK/session.json")"
[ -n "$ACCESS" ] && ok 'the session carries an access token' || bad 'no access token in the session'
expect 'the address is confirmed' "$EMAIL" "$(json user.email < "$WORK/session.json")"
[ -n "$(json user.email_confirmed_at < "$WORK/session.json")" ] \
  && ok 'email_confirmed_at is set, so no confirmation link is needed' \
  || bad 'email_confirmed_at is empty'

# --- the session is a real one --------------------------------------------
printf '\nRLS\n'

SELECT='id,role,referral_code,display_name'
CODE="$(curl -s -o "$WORK/profiles.json" -w '%{http_code}' "$URL/rest/v1/profiles?select=$SELECT" \
  -H "apikey: $KEY" -H "Authorization: Bearer $ACCESS")"
expect 'the session can read its own profile' 200 "$CODE"
expect 'the signup trigger created exactly one profile' 1 \
  "$(python3 -c '
import json, sys
rows = json.load(open(sys.argv[1]))
print(len(rows) if isinstance(rows, list) else "not a list")
' "$WORK/profiles.json")"
expect 'the profile belongs to the signed-in user' "$USER_ID" "$(json 0.id < "$WORK/profiles.json")"
# handle_new_user names the profile after the address, which proves the trigger
# ran for the user this sandbox session created.
expect 'the profile is named after the address' "${EMAIL%%@*}" "$(json 0.display_name < "$WORK/profiles.json")"

# Same query with no token. The migration revokes everything from anon and
# grants nothing back for profiles, so this must be refused outright rather than
# returning an empty set.
CODE="$(curl -s -o "$WORK/anon.json" -w '%{http_code}' "$URL/rest/v1/profiles?select=$SELECT" -H "apikey: $KEY")"
expect 'an anonymous read is refused outright' "401 42501" "$CODE $(json code < "$WORK/anon.json")"

# --- the catalogue the home screen needs ----------------------------------
printf '\ncatalogue\n'

# The exact select the app builds, embedded relations included. It drifted once
# before, which broke the whole catalogue page as soon as real data existed, so
# the shape is checked rather than assumed.
SEL='id, slug, name_km, name_en, image_url, kind, rating_avg, rating_count, sold_count, category:categories ( id, slug, name_km, name_en ), variants:product_variants ( id, sku, label_km, label_en, price_usd, compare_at_price_usd, stock_mode, min_qty, max_qty )'
CODE="$(curl -s -o "$WORK/products.json" -w '%{http_code}' -G "$URL/rest/v1/products" \
  --data-urlencode "select=$SEL" --data-urlencode "order=sort_order" --data-urlencode "limit=48" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY")"
expect 'the home query answers' 200 "$CODE"
expect 'every product card is renderable' ok "$(python3 -c '
import json, sys
rows = json.load(open(sys.argv[1]))
if isinstance(rows, dict):
    print("query failed: " + str(rows)[:140]); raise SystemExit(0)
if not rows:
    print("no products at all; run supabase db reset to load supabase/seed/demo.sql")
    raise SystemExit(0)
bad = []
for row in rows:
    slug = row.get("slug", "?")
    if not row.get("variants"):
        bad.append(slug + " has no variants")
    for column in ("name_km", "name_en", "image_url"):
        if not row.get(column):
            bad.append("%s.%s is null" % (slug, column))
print("; ".join(bad) if bad else "ok")
' "$WORK/products.json")"

CODE="$(curl -s -o "$WORK/categories.json" -w '%{http_code}' \
  "$URL/rest/v1/categories?select=id,slug,name_km,name_en&order=sort_order" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY")"
expect 'the category list answers' 200 "$CODE"
expect 'the category list is populated' ok "$(python3 -c '
import json, sys
rows = json.load(open(sys.argv[1]))
if isinstance(rows, dict) or not rows:
    print("empty; run supabase db reset to load supabase/seed/demo.sql")
else:
    print("ok")
' "$WORK/categories.json")"

# --- checkout pays end to end ---------------------------------------------
printf '\ncheckout -> paid\n'

PAY_MODE="on"
CODE="$(curl -s -o "$WORK/payway_probe.json" -w '%{http_code}' -X POST "$URL/functions/v1/payway-init" \
  -H "apikey: $KEY" -H 'Content-Type: application/json' \
  -d '{"orderId":"00000000-0000-0000-0000-000000000000"}')"
# The config check runs before auth, so an unconfigured project answers 503
# whatever we send.
if [ "$(json error < "$WORK/payway_probe.json")" = "payway_not_configured" ]; then
  PAY_MODE="off"
fi

# Read rather than guess: the stub marks its QR strings, and that assertion must
# not fire against a real sandbox.
FUNC_PAYWAY_ENV="$(grep -m1 '^PAYWAY_ENV=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)"

pick_variant() {
  curl -s -G "$URL/rest/v1/product_variants" \
    --data-urlencode 'select=id,sku,stock_mode,product:products(kind,requires_fields)' \
    -H "apikey: $KEY" -H "Authorization: Bearer $ACCESS" | python3 -c '
import json, sys, re

# Prefer a repeatable order: unlimited stock, delivered automatically, and only
# digit-shaped required fields so a dummy value can satisfy the pattern.
rows = json.load(sys.stdin)
if not isinstance(rows, list) or not rows:
    raise SystemExit(0)

def rank(row):
    product = row["product"] or {}
    fields = product.get("requires_fields") or []
    unlimited = row["stock_mode"] == "unlimited"
    automatic = product.get("kind") == "auto_topup"
    digits = all(
        re.fullmatch(r"\^\[0-9\]\{\d+,\d+\}\$", f.get("pattern", "")) for f in fields
    )
    return 0 if unlimited and automatic and digits else 1 if unlimited and not fields else 2

rows.sort(key=rank)
row = rows[0]
fields = {}
for field in (row["product"].get("requires_fields") or []):
    match = re.fullmatch(r"\^\[0-9\]\{(\d+),(\d+)\}\$", field.get("pattern", ""))
    fields[field["key"]] = "1" * (int(match.group(1)) if match else 6)

print(json.dumps({"id": row["id"], "sku": row["sku"], "fields": fields}))
'
}

pay_cycle() { # $1 = label; leaves $CYCLE_ORDER_ID and $WORK/*.json behind
  VARIANT="$(pick_variant)"
  if [ -z "$VARIANT" ]; then
    bad "$1: no purchasable variant in the catalogue"
    return 1
  fi

  CYCLE_SKU="$(printf '%s' "$VARIANT" | json sku)"
  ORDER_BODY="$(python3 -c '
import json, sys
print(json.dumps({
    "p_items": [{"variant_id": int(sys.argv[1]), "qty": 1}],
    "p_fields": json.loads(sys.argv[2]),
}))
' "$(printf '%s' "$VARIANT" | json id)" \
   "$(printf '%s' "$VARIANT" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["fields"]))')")"

  curl -s -o "$WORK/order.json" -X POST "$URL/rest/v1/rpc/create_order" \
    -H "apikey: $KEY" -H "Authorization: Bearer $ACCESS" \
    -H 'Content-Type: application/json' -d "$ORDER_BODY"
  CYCLE_ORDER_ID="$(json order_id < "$WORK/order.json")"
  if [ -z "$CYCLE_ORDER_ID" ]; then
    bad "$1: create_order refused: $(head -c 140 "$WORK/order.json")"
    return 1
  fi
  ok "$1: created an order for $CYCLE_SKU"

  CODE="$(curl -s -o "$WORK/init.json" -w '%{http_code}' -X POST "$URL/functions/v1/payway-init" \
    -H "apikey: $KEY" -H "Authorization: Bearer $ACCESS" \
    -H 'Content-Type: application/json' -d "{\"orderId\":\"$CYCLE_ORDER_ID\"}")"
  expect "$1: payway-init issues a payment" 200 "$CODE"

  CYCLE_QR="$(json qr_string < "$WORK/init.json")"
  if [ -n "$CYCLE_QR" ]; then
    ok "$1: a QR string comes back, which is what the sheet renders"
  else
    bad "$1: no qr_string: $(head -c 140 "$WORK/init.json")"
  fi
  if [ "$FUNC_PAYWAY_ENV" = "stub" ]; then
    case "$CYCLE_QR" in
      STUB*) ok "$1: the stub QR says STUB, so it cannot pass for a real code" ;;
      *) bad "$1: the stub QR is not marked: $CYCLE_QR" ;;
    esac
  fi

  # The app polls, so the first answer here is kept separately: with the stub in
  # its realistic mode it must be PENDING, otherwise the sheet closes instantly.
  curl -s -o "$WORK/verify_first.json" -X POST "$URL/functions/v1/payway-verify" \
    -H "apikey: $KEY" -H "Authorization: Bearer $ACCESS" \
    -H 'Content-Type: application/json' -d "{\"orderId\":\"$CYCLE_ORDER_ID\"}"
  cp "$WORK/verify_first.json" "$WORK/verify.json"
  return 0
}

# Polls like KhqrSheet does, up to 25s, and leaves the settling answer in
# $WORK/verify.json. Returns 1 if it never reached a final state.
pay_verify_until_settled() {
  local deadline=$((SECONDS + 25))
  while :; do
    case "$(json ok < "$WORK/verify.json"):$(json state < "$WORK/verify.json")" in
      true:* | false:DECLINED | false:CANCELLED) return 0 ;;
    esac
    if [ "$SECONDS" -ge "$deadline" ]; then return 1; fi
    sleep 2
    curl -s -o "$WORK/verify.json" -X POST "$URL/functions/v1/payway-verify" \
      -H "apikey: $KEY" -H "Authorization: Bearer $ACCESS" \
      -H 'Content-Type: application/json' -d "{\"orderId\":\"$CYCLE_ORDER_ID\"}"
  done
}

if [ "$PAY_MODE" = "off" ]; then
  printf '  \033[33mSKIP\033[0m PayWay is not configured, so payway-init answers 503 and nothing\n'
  printf '       in checkout can pay. Turn on the stub: PAYWAY_ENV=stub in\n'
  printf '       supabase/functions/.env, then supabase stop && supabase start.\n'
else
  if pay_cycle "checkout"; then
    # The bug this guards: a stub that approves on the first poll makes the QR
    # sheet flash open and shut, so nobody can test the payment screen.
    expect 'checkout: the first poll is PENDING, so the sheet stays open' PENDING \
      "$(json state < "$WORK/verify_first.json")"

    if pay_verify_until_settled; then
      expect 'checkout: settlement approves the payment' true "$(json ok < "$WORK/verify.json")"
      CYCLE_STATUS="$(json order_status < "$WORK/verify.json")"
      case "$CYCLE_STATUS" in
        delivered | paid | delivering)
          ok "checkout: the order moved to $CYCLE_STATUS"
          ;;
        *)
          bad "checkout: the order stayed $CYCLE_STATUS — $(json reason < "$WORK/verify.json")"
          ;;
      esac

      # The row is the truth the app reads back, not the function's answer.
      curl -s -o "$WORK/order_row.json" \
        "$URL/rest/v1/orders?select=status,total_usd&id=eq.$CYCLE_ORDER_ID" \
        -H "apikey: $KEY" -H "Authorization: Bearer $ACCESS"
      expect 'checkout: the stored order agrees' "$CYCLE_STATUS" "$(json 0.status < "$WORK/order_row.json")"
    else
      bad "checkout: never settled, last state $(json state < "$WORK/verify.json")"
    fi
  fi
fi

# --- repeatable and forgiving input ---------------------------------------
printf '\nrepeat and normalise\n'

CODE="$(curl -s -o "$WORK/again.json" -w '%{http_code}' -X POST "$ENDPOINT" "${AUTH_HEADERS[@]}" \
  -d "{\"email\":\"$EMAIL\",\"code\":\"$OTP\"}")"
expect 'the same address can sign in again' 200 "$CODE"

MESSY="  Sandbox-$(date +%s)@Example.COM "
CODE="$(curl -s -o "$WORK/messy.json" -w '%{http_code}' -X POST "$ENDPOINT" "${AUTH_HEADERS[@]}" \
  -d "{\"email\":\"$MESSY\",\"code\":\"$OTP\"}")"
expect 'a padded, mixed-case address is accepted' 200 "$CODE"

MESSY_HASH="$(json token_hash < "$WORK/messy.json")"
EXPECTED_EMAIL="$(printf '%s' "$MESSY" | tr 'A-Z' 'a-z' | xargs)"
CODE="$(curl -s -o "$WORK/messy_session.json" -w '%{http_code}' -X POST "$URL/auth/v1/verify" "${AUTH_HEADERS[@]}" \
  -d "{\"type\":\"magiclink\",\"token_hash\":\"$MESSY_HASH\"}")"
expect 'and it signs in' 200 "$CODE"
expect 'and it is stored normalised' "$EXPECTED_EMAIL" "$(json user.email < "$WORK/messy_session.json")"

# --- the stub's failure branches ------------------------------------------
if [ "${1:-}" = "--check-payway" ]; then
  printf '\nfailure branches (stops and starts the stack three times, ~2 min)\n'

  if [ "$FUNC_PAYWAY_ENV" != "stub" ]; then
    printf '  \033[33mSKIP\033[0m needs PAYWAY_ENV=stub in supabase/functions/.env.\n'
  elif [ ! -f "$ENV_FILE" ]; then
    bad "$ENV_FILE is missing, so this check cannot run"
  else
    cp "$ENV_FILE" "$WORK/functions.env"
    RESTORING="yes"

    set_function_env() { # NAME=VALUE, an empty value removes the line
      local name="${1%%=*}"
      grep -v "^${name}=" "$ENV_FILE" > "$WORK/env.tmp" || true
      if [ -n "${1#*=}" ]; then printf '%s\n' "$1" >> "$WORK/env.tmp"; fi
      cp "$WORK/env.tmp" "$ENV_FILE"
    }

    order_status() {
      curl -s "$URL/rest/v1/orders?select=status&id=eq.$CYCLE_ORDER_ID" \
        -H "apikey: $KEY" -H "Authorization: Bearer $ACCESS" |
        python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["status"])'
    }

    # ABA declines: the order must not move.
    set_function_env PAYWAY_STUB_SETTLE_SECONDS=0
    set_function_env PAYWAY_STUB_STATE=DECLINED
    if restart_stack && wait_for_runtime && pay_cycle 'declined'; then
      expect 'declined: settlement does not approve' false "$(json ok < "$WORK/verify.json")"
      expect 'declined: the answer names the state' DECLINED "$(json state < "$WORK/verify.json")"
      expect 'declined: the order stays pending' pending "$(order_status)"
    else
      bad 'declined: the stack or the order could not be set up'
    fi

    # ABA approves, but for less than the order total. Delivery must be refused.
    set_function_env PAYWAY_STUB_STATE=
    set_function_env PAYWAY_STUB_UNDERPAY=1
    if restart_stack && wait_for_runtime && pay_cycle 'underpaid'; then
      expect 'underpaid: settlement refuses' false "$(json ok < "$WORK/verify.json")"
      case "$(json reason < "$WORK/verify.json")" in
        underpaid*)
          ok "underpaid: the reason names the shortfall ($(json reason < "$WORK/verify.json"))"
          ;;
        *)
          bad "underpaid: unexpected reason $(json reason < "$WORK/verify.json")"
          ;;
      esac
      expect 'underpaid: the order stays pending' pending "$(order_status)"
    else
      bad 'underpaid: the stack or the order could not be set up'
    fi

    # Hand the environment back exactly as it was found.
    cp "$WORK/functions.env" "$ENV_FILE"
    RESTORING=""
    restart_stack && wait_for_runtime || bad 'the stack did not come back up'
  fi
fi

# --- unset DEV_OTP and the endpoint must go dark --------------------------
if [ "${1:-}" = "--check-disabled" ]; then
  printf '\nkill switch (stops and starts the stack, ~60s)\n'

  if [ ! -f "$ENV_FILE" ]; then
    bad "$ENV_FILE is missing, so this check cannot run"
  else
    cp "$ENV_FILE" "$WORK/functions.env"
    RESTORING="yes"
    grep -v '^DEV_OTP=' "$ENV_FILE" > "$WORK/without.env"
    cp "$WORK/without.env" "$ENV_FILE"

    if restart_stack && wait_for_runtime; then
      CODE="$(curl -s -o "$WORK/disabled.json" -w '%{http_code}' -X POST "$ENDPOINT" "${AUTH_HEADERS[@]}" \
        -d "{\"email\":\"$EMAIL\",\"code\":\"$OTP\"}")"
      expect 'with DEV_OTP unset the endpoint answers 404' 404 "$CODE"
    else
      bad 'the stack did not come back up after removing DEV_OTP'
    fi

    # Put it back and prove the endpoint recovers, so a failed run cannot leave
    # the sandbox broken.
    cp "$WORK/functions.env" "$ENV_FILE"
    RESTORING=""
    if restart_stack && wait_for_runtime; then
      CODE="$(curl -s -o "$WORK/recovered.json" -w '%{http_code}' -X POST "$ENDPOINT" "${AUTH_HEADERS[@]}" \
        -d "{\"email\":\"$EMAIL\",\"code\":\"$OTP\"}")"
      expect 'and answers again once DEV_OTP is restored' 200 "$CODE"
    else
      bad 'the stack did not come back up after restoring DEV_OTP'
    fi
  fi
fi

# --- summary --------------------------------------------------------------
printf '\n\033[1m%d passed, %d failed\033[0m\n' "$PASS" "$FAIL"

# Informational, not a pass/fail: a dev environment may legitimately have no
# PayWay credentials. What matters is that the reason is visible instead of
# looking like a broken checkout.
case "$PAY_MODE $FUNC_PAYWAY_ENV" in
  'off '*)
    printf '\033[33mPayWay: not configured.\033[0m Checkout and wallet top-up cannot pay.\n'
    printf 'For a working dev flow set PAYWAY_ENV=stub in supabase/functions/.env, then\n'
    printf 'supabase stop && supabase start. For real sandbox payments use PAYWAY_ENV=sandbox\n'
    printf 'with the merchant id and API key from https://sandbox.payway.com.kh.\n'
    ;;
  'on stub')
    printf '\033[33mPayWay: sandbox stub.\033[0m QRs are marked STUB and ABA is never called.\n'
    printf 'Set PAYWAY_ENV=sandbox with real credentials before trusting a payment test.\n'
    ;;
  'on sandbox' | 'on production')
    printf '\033[32mPayWay: configured against %s.\033[0m Payments reach ABA.\n' "$FUNC_PAYWAY_ENV"
    ;;
  *)
    printf '\033[33mPayWay: unexpected state (%s).\033[0m\n' "$PAY_MODE $FUNC_PAYWAY_ENV"
    ;;
esac

if [ "$FAIL" -eq 0 ]; then
  printf 'No email was sent. Codes in Mailpit: %s\n' "${MAILPIT_URL:-http://127.0.0.1:54324}"
fi

[ "$FAIL" -eq 0 ] || exit 1
