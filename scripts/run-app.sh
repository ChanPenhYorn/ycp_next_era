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

die() { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

[ -f "$ENV_FILE" ] || die "$ENV_FILE not found. cp .env.local.example .env.local"

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

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

printf '\n\033[1m==> Starting Sela against %s\033[0m\n' "$SUPABASE_URL"

cd "$ROOT/app"
exec flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$KEY" \
  "$@"
