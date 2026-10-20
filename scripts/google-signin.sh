#!/usr/bin/env bash
#
# Google sign-in against the LOCAL stack.
#
#   ./scripts/google-signin.sh --on      # enable the provider and restart
#   ./scripts/google-signin.sh --off     # disable it and restart
#   ./scripts/google-signin.sh --status  # what the auth server reports now
#
# Why a script: `[auth.external.google] enabled` is a committed boolean and the
# Supabase CLI cannot read a bool from the environment (`env(...)` there is a
# config parse error), so it has to be flipped in config.toml. This script flips
# it, restarts, then puts config.toml back exactly as committed. The running
# container keeps the provider on until the next `supabase stop`.
#
# The client id and secret are read from the shell, else from .env.local:
#
#   SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=...apps.googleusercontent.com
#   SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=GOCSPX-...
#
# The Google OAuth client needs this exact authorised redirect URI:
#
#   http://127.0.0.1:54321/auth/v1/callback
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/supabase/config.toml"
ENV_FILE="$ROOT/.env.local"
APP_CONFIG="$ROOT/app/config/dev.json"
BACKUP=""

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }
die() { printf '\n\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

restore_config() {
  if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
    mv "$BACKUP" "$CONFIG"
    BACKUP=""
  fi
}

trap restore_config EXIT INT TERM

# --- credentials -----------------------------------------------------------
from_env_file() {
  [ -f "$ENV_FILE" ] || return 0
  grep -m1 "^$1=" "$ENV_FILE" | cut -d= -f2-
}

CLIENT_ID="${SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID:-$(from_env_file SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID)}"
CLIENT_SECRET="${SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET:-$(from_env_file SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)}"

# --- config.toml edit ------------------------------------------------------
# Only touch the value inside [auth.external.google]; other sections also have
# `enabled = ...` lines.
set_provider() {
  local on_off="$1"
  BACKUP="$(mktemp "$CONFIG.XXXXXX")"
  cp "$CONFIG" "$BACKUP"
  python3 - "$CONFIG" "$on_off" <<'PY'
import re, sys
path, value = sys.argv[1], "true" if sys.argv[2] == "true" else "false"
text = open(path).read()
pattern = re.compile(r"(\[auth\.external\.google\]\n(?:[^\[]*?))enabled\s*=\s*(?:true|false)")
new, count = pattern.subn(lambda m: m.group(1) + "enabled = " + value, text, count=1)
if count != 1:
    sys.exit("[auth.external.google] enabled line not found")
open(path, "w").write(new)
PY
  [ $? -eq 0 ] || die "could not edit $CONFIG"
}

publishable_key() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["SUPABASE_PUBLISHABLE_KEY"])' "$APP_CONFIG" 2>/dev/null
}

api_url() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["SUPABASE_URL"])' "$APP_CONFIG" 2>/dev/null
}

report() {
  local url key settings
  url="$(api_url)"
  key="$(publishable_key)"
  [ -n "$url" ] && [ -n "$key" ] || die "app/config/dev.json is missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY"
  settings="$(curl -s "$url/auth/v1/settings" -H "apikey: $key")" || die "auth server unreachable at $url"
  case "$settings" in
    *'"google":true'*) note "provider: ON  ($url)" ;;
    *'"google":false'*) note "provider: off ($url)" ;;
    *) note "provider: unknown (settings call returned: ${settings:0:120})" ;;
  esac
}

authorize_check() {
  local url key location
  url="$(api_url)"
  key="$(publishable_key)"
  location="$(curl -s -o /dev/null -w '%{redirect_url}' \
    "$url/auth/v1/authorize?provider=google&redirect_to=http://localhost:8080" \
    -H "apikey: $key")"
  case "$location" in
    *accounts.google.com*)
      note "authorize: redirects to Google"
      note "client_id: $(printf '%s' "$location" | sed -n 's/.*client_id=\([^&]*\).*/\1/p')"
      note "redirect_uri: $(printf '%s' "$location" | sed -n 's/.*redirect_uri=\([^&]*\).*/\1/p' | python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))')"
      ;;
    *)
      note "authorize: no Google redirect (got: ${location:0:160})"
      ;;
  esac
}

need_credentials() {
  [ -n "$CLIENT_ID" ] || die "SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID is empty (shell or .env.local)"
  [ -n "$CLIENT_SECRET" ] || die "SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET is empty (shell or .env.local)"
  case "$CLIENT_ID" in
    *apps.googleusercontent.com) ;;
    *) die "client id does not look like ...apps.googleusercontent.com" ;;
  esac
}

restart_stack() {
  command -v supabase >/dev/null 2>&1 || die "the supabase CLI is not on PATH"
  docker info >/dev/null 2>&1 || die "Docker is not running"
  step "Restarting the stack"
  # The CLI bakes [auth.external.google] into the auth container at creation, so
  # a plain restart keeps the old values.
  (cd "$ROOT" && supabase stop >/dev/null 2>&1)
  (cd "$ROOT" && SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID="$CLIENT_ID" \
    SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET="$CLIENT_SECRET" \
    supabase start >/dev/null) || die "supabase start failed. Run it directly to see why."
}

case "${1:-}" in
  --on|on|enable)
    need_credentials
    step "Enabling Google for the local stack"
    set_provider true
    restart_stack
    restore_config
    step "Checking"
    report
    authorize_check
    note "config.toml put back; the provider stays on until the next supabase stop."
    ;;
  --off|off|disable)
    step "Disabling Google for the local stack"
    set_provider false
    restart_stack
    restore_config
    step "Checking"
    report
    ;;
  --status|status)
    step "Auth provider status"
    report
    authorize_check
    ;;
  *)
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac
