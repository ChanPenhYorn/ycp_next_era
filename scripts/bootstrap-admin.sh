#!/usr/bin/env bash
#
# Makes one existing account the store's first admin.
#
#   ./scripts/bootstrap-admin.sh              # hosted: reads ADMIN_EMAIL from .env.local
#   ./scripts/bootstrap-admin.sh --local      # local stack
#   ./scripts/bootstrap-admin.sh you@x.com    # explicit address
#
# The account must already exist: sign up in the app first. Admins then manage
# staff in the app (/admin/staff). Run this once per project; re-running is
# harmless.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.local}"
LOCAL_DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

die() { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

command -v supabase >/dev/null 2>&1 || die "Supabase CLI not found."

target="local"
email=""
for arg in "$@"; do
  case "$arg" in
    --local) target="local" ;;
    --*) die "unknown flag: $arg" ;;
    *) email="$arg" ;;
  esac
done

if [ -z "$email" ]; then
  [ -f "$ENV_FILE" ] || die "$ENV_FILE not found. Set ADMIN_EMAIL there or pass the address."
  email="$(grep -E '^ADMIN_EMAIL=' "$ENV_FILE" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
  target="hosted"
fi

[ -n "$email" ] || die "no admin email given (ADMIN_EMAIL is empty)"
case "$email" in
  *@*.*) ;;
  *) die "not an email address: $email" ;;
esac
case "$email" in
  *\'*) die "email contains a quote character: $email" ;;
esac

sql="select public.bootstrap_admin('$email');"

if [ "$target" = "local" ]; then
  supabase db query --db-url "$LOCAL_DB_URL" "$sql" >/dev/null || die "bootstrap failed. Did $email sign up on the local app?"
  echo "local: $email is now admin"
else
  supabase db query --linked "$sql" >/dev/null || die "bootstrap failed. Sign up with $email in the app first, then re-run."
  echo "hosted: $email is now admin"
fi
