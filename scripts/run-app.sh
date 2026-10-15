#!/usr/bin/env bash
#
# Runs the app with credentials read from .env.local, so the publishable key
# never has to be pasted into launch.json (which is a tracked file).
#
#   ./scripts/run-app.sh                 # default device
#   ./scripts/run-app.sh -d chrome       # browser
#   ./scripts/run-app.sh -d macos
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.local}"

# Captured before the env file is sourced: the environment overrides the file.
PRE_SUPABASE_URL="${SUPABASE_URL:-}"
PRE_SUPABASE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}"
PRE_DEV_OTP="${DEV_OTP:-}"

die() { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

[ -f "$ENV_FILE" ] || die "$ENV_FILE not found. cp .env.local.example .env.local"

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

# A value already in the environment wins over the file, so a one-off
# `SUPABASE_URL=http://127.0.0.1:54321 ./scripts/run-app.sh` means what it says.
if [ -n "${PRE_SUPABASE_URL:-}" ]; then
  SUPABASE_URL="$PRE_SUPABASE_URL"
fi
if [ -n "${PRE_SUPABASE_KEY:-}" ]; then
  SUPABASE_PUBLISHABLE_KEY="$PRE_SUPABASE_KEY"
fi
if [ -n "${PRE_DEV_OTP:-}" ]; then
  DEV_OTP="$PRE_DEV_OTP"
fi

[ -n "${SUPABASE_URL:-}" ] || die "SUPABASE_URL is empty in $ENV_FILE"

KEY="${SUPABASE_PUBLISHABLE_KEY:-}"
if [ -z "$KEY" ]; then
  die "SUPABASE_PUBLISHABLE_KEY is empty in $ENV_FILE
Find it at Dashboard -> Settings -> API -> publishable key."
fi

# Refuse to run with a privileged key: it would ship inside the app bundle.
case "$KEY" in
  sb_secret_*|*service_role*)
    die "SUPABASE_PUBLISHABLE_KEY looks like a secret key.
It bypasses RLS and must never be compiled into the app." ;;
esac

printf '\n\033[1m==> Starting Chanpenh against %s\033[0m\n' "$SUPABASE_URL"

DEFINES=(
  --dart-define=SUPABASE_URL="$SUPABASE_URL"
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$KEY"
)

# Sandbox sign-in. The app only honours this on a loopback URL, but say it out
# loud anyway so nobody wonders where the email went.
if [ -n "${DEV_OTP:-}" ]; then
  printf '\033[1m==> Sandbox sign-in: code %s, no email is sent\033[0m\n' "$DEV_OTP"
  DEFINES+=(--dart-define=DEV_OTP="$DEV_OTP")
fi

cd "$ROOT/app"
exec flutter run "${DEFINES[@]}" "$@"
