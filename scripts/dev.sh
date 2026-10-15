#!/usr/bin/env bash
#
# Brings the whole local environment up in one command.
#
#   ./scripts/dev.sh                  # stack up, seeded, verified, app in Chrome
#   ./scripts/dev.sh -d macos         # same, on another device
#   ./scripts/dev.sh --reset          # wipe and re-seed the database first
#   ./scripts/dev.sh --no-run         # set everything up, do not launch the app
#   ./scripts/dev.sh --reload-functions  # after editing an Edge Function
#
# It is safe to run repeatedly: every step checks the current state before
# changing anything, and nothing is destructive unless --reset is passed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/app/config/dev.json"
FUNC_ENV="$ROOT/supabase/functions/.env"
FUNC_ENV_EXAMPLE="$ROOT/supabase/functions/.env.example"

RUN_APP=1
VERIFY=1
RESET=0
RELOAD=0
FLUTTER_ARGS=()

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }
die() { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --reset) RESET=1 ;;
    --no-verify) VERIFY=0 ;;
    --no-run) RUN_APP=0 ;;
    --reload-functions) RELOAD=1 ;;
    *) FLUTTER_ARGS+=("$arg") ;;
  esac
done

# --- 1. the tools have to be there ----------------------------------------
command -v supabase >/dev/null 2>&1 || die "The supabase CLI is not on PATH."
command -v python3 >/dev/null 2>&1 || die "python3 is not on PATH."
docker info >/dev/null 2>&1 || die "Docker is not running. Start Docker Desktop first."

[ -f "$CONFIG" ] || die "$CONFIG is missing."

URL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["SUPABASE_URL"])' "$CONFIG")"
KEY="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["SUPABASE_PUBLISHABLE_KEY"])' "$CONFIG")"
[ -n "$URL" ] && [ -n "$KEY" ] || die "$CONFIG needs SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY."

# --- 2. the function environment ------------------------------------------
step "Function environment"
if [ ! -f "$FUNC_ENV" ]; then
  [ -f "$FUNC_ENV_EXAMPLE" ] || die "$FUNC_ENV is missing and there is no example to copy."
  cp "$FUNC_ENV_EXAMPLE" "$FUNC_ENV"
  note "created supabase/functions/.env from the example"
else
  note "supabase/functions/.env present"
fi
note "PAYWAY_ENV=$(grep -m1 '^PAYWAY_ENV=' "$FUNC_ENV" | cut -d= -f2- || echo '')"
note "DEV_OTP=$(grep -m1 '^DEV_OTP=' "$FUNC_ENV" | cut -d= -f2- || echo '')"

# --- 3. the stack ----------------------------------------------------------
step "Local stack"
if supabase status >/dev/null 2>&1; then
  note "already running"
else
  note "starting (first run pulls images, this takes a while)"
  (cd "$ROOT" && supabase start >/dev/null 2>&1) || die "supabase start failed. Run it directly to see why."
fi

# --- 4. reset, or seed an empty database ----------------------------------
products_here() {
  curl -s -G "$URL/rest/v1/products" --data-urlencode 'select=id' --data-urlencode 'limit=1' \
    -H "apikey: $KEY" -H "Authorization: Bearer $KEY" 2>/dev/null
}

step "Database"
if [ "$RESET" = "1" ]; then
  note "--reset: applying migrations and supabase/seed/demo.sql"
  (cd "$ROOT" && supabase db reset >/dev/null 2>&1) || die "supabase db reset failed."
elif [ "$(products_here)" = "[]" ]; then
  note "no products found, seeding with supabase/seed/demo.sql"
  (cd "$ROOT" && supabase db reset >/dev/null 2>&1) || die "supabase db reset failed."
else
  note "catalogue already seeded"
fi

# --- 5. reload the Edge Functions after an edit ---------------------------
if [ "$RELOAD" = "1" ]; then
  step "Reloading Edge Functions"
  runtime="$(docker ps --filter name=supabase_edge_runtime --format '{{.Names}}' | head -1)"
  [ -n "$runtime" ] || die "No edge runtime container. Is the stack up?"
  docker restart "$runtime" >/dev/null || die "Could not restart $runtime."
  for _ in $(seq 1 60); do
    code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/functions/v1/dev-signin" \
      -H "apikey: $KEY" -H 'Content-Type: application/json' \
      -d '{"email":"probe@example.com","code":"000000"}' 2>/dev/null)"
    case "$code" in 2* | 4*) break ;; esac
    sleep 1
  done
  note "restarted $runtime"
  note "function *code* changes need this; function *env* changes need --reset of the stack"
fi

# --- 6. prove it works ----------------------------------------------------
if [ "$VERIFY" = "1" ]; then
  step "Verifying"
  "$ROOT/scripts/verify-sandbox.sh" || die "Sandbox verification failed. See the list above."
fi

# --- 7. launch ------------------------------------------------------------
if [ "$RUN_APP" = "1" ]; then
  has_device=0
  for arg in ${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"}; do
    case "$arg" in -d | --device) has_device=1 ;; esac
  done
  if [ "$has_device" = "0" ]; then
    FLUTTER_ARGS=(-d chrome ${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"})
  fi
  exec "$ROOT/scripts/run-sandbox.sh" "${FLUTTER_ARGS[@]}"
else
  step "Ready"
  note "start the app with: ./scripts/run-sandbox.sh -d chrome"
fi
