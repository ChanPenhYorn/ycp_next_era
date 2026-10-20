#!/usr/bin/env bash
#
# The timer nothing else provides.
#
#   ./scripts/supplier-worker.sh                  run every 30s until stopped
#   ./scripts/supplier-worker.sh --interval 10    tighter loop
#   ./scripts/supplier-worker.sh --once           one pass, for a test
#   ./scripts/supplier-worker.sh --once --limit 1 one line only
#   ./scripts/supplier-worker.sh --dry-run        show what it would call, spend nothing
#   ./scripts/supplier-worker.sh --stop           stop a loop left running
#
# `supplier-fulfil` is what turns a paid auto top-up into a delivered one, and
# `telegram-dispatch` flushes the buyer notifications. Neither is called by
# anything on a schedule: an order waits in `delivering` until someone posts
# the function by hand. This loop is the local stand-in for the hosted
# schedule (see docs/hosted-deploy.md) and `scripts/dev.sh` starts it for you.
#
# WARNING: while BAY2GAME_API_KEY is a live key, each pass places REAL orders
# with the supplier and spends REAL balance. That is the point of it, and it
# is not free. Point it at a sandbox key when you are only testing.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FUNC_ENV="$ROOT/supabase/functions/.env"
STATE_DIR="$ROOT/.dev"
PIDFILE="$STATE_DIR/supplier-worker.pid"
LOGFILE="$STATE_DIR/supplier-worker.log"

INTERVAL=30
ONCE=0
STOP=0
DRY=0
LIMIT=20

while [ $# -gt 0 ]; do
  case "$1" in
    --once) ONCE=1 ;;
    --stop) STOP=1 ;;
    --dry-run) DRY=1 ;;
    --limit)
      LIMIT="${2:-}"
      shift
      ;;
    --interval)
      INTERVAL="${2:-}"
      shift
      ;;
    -h | --help)
      sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

mkdir -p "$STATE_DIR"

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

pid_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }

running_pid() { [ -f "$PIDFILE" ] && cat "$PIDFILE"; }

if [ "$STOP" = "1" ]; then
  pid="$(running_pid)"
  if pid_alive "$pid"; then
    kill "$pid" 2>/dev/null
    rm -f "$PIDFILE"
    echo "stopped supplier worker (pid $pid)"
  else
    rm -f "$PIDFILE"
    echo "no supplier worker running"
  fi
  exit 0
fi

existing="$(running_pid)"
if pid_alive "$existing"; then
  echo "supplier worker already running (pid $existing). Stop it with --stop." >&2
  exit 0
fi

command -v supabase >/dev/null 2>&1 || { echo "the supabase CLI is not on PATH" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is not on PATH" >&2; exit 1; }

# `verify_jwt = true` on both workers, so these need a real JWT. The
# publishable key is not one; the local anon key is.
env_value() { supabase status -o env 2>/dev/null | sed -n "s/^$1=\"\(.*\)\"$/\1/p" | head -1; }

JWT="$(env_value ANON_KEY)"
FUNCTIONS_URL="$(env_value FUNCTIONS_URL)"

if [ -z "$JWT" ] || [ -z "$FUNCTIONS_URL" ]; then
  echo "cannot read the local stack's JWT or URL. Is it running? (supabase start)" >&2
  exit 1
fi

# Read the last assignment so a later line wins, as the runtime does.
JOB_SECRET=""
DISPATCH_SECRET=""
if [ -f "$FUNC_ENV" ]; then
  JOB_SECRET="$(grep -E '^SUPPLIER_JOB_SECRET=' "$FUNC_ENV" | tail -1 | cut -d= -f2-)"
  DISPATCH_SECRET="$(grep -E '^TELEGRAM_DISPATCH_SECRET=' "$FUNC_ENV" | tail -1 | cut -d= -f2-)"
fi
if [ -z "$JOB_SECRET" ]; then
  log "SUPPLIER_JOB_SECRET is unset, so the workers accept any caller (local only)"
fi

if [ "$DRY" = "1" ]; then
  # Proves the plumbing without placing a single supplier order.
  printf 'functions:  %s\n' "$FUNCTIONS_URL"
  printf 'jwt:        %s\n' "$([ -n "$JWT" ] && echo 'read from the local stack' || echo 'MISSING')"
  printf 'job secret: %s\n' "$([ -n "$JOB_SECRET" ] && echo 'set' || echo 'unset (accepted locally)')"
  printf 'dispatch:   %s\n' "$([ -n "$DISPATCH_SECRET" ] && echo 'secret set' || echo 'no secret (accepted locally)')"
  printf 'endpoints:  %s\n' "$FUNCTIONS_URL/supplier-fulfil $FUNCTIONS_URL/telegram-dispatch"
  printf 'interval:   %ss\n' "$INTERVAL"
  printf 'log:        %s\n' "$LOGFILE"
  exit 0
fi

post() {
  local name="$1" body="$2"
  local headers=(-H "Authorization: Bearer $JWT" -H 'Content-Type: application/json')
  if [ -n "$JOB_SECRET" ]; then
    headers+=(-H "x-job-secret: $JOB_SECRET")
  fi
  if [ -n "$DISPATCH_SECRET" ]; then
    headers+=(-H "x-dispatch-secret: $DISPATCH_SECRET")
  fi
  curl -sS -m 60 -X POST "$FUNCTIONS_URL/$name" "${headers[@]}" -d "$body" 2>/dev/null
}

# Every count the function reports, whatever they are called: the two workers
# do not share a response shape.
summarise() {
  python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("unreadable answer")
    raise SystemExit(0)
if "error" in d:
    print("error", d.get("error"), d.get("detail", ""))
    raise SystemExit(0)
print(" ".join(f"{k}={v}" for k, v in d.items() if k != "ok"))
'
}

# "processed=0 delivered=0" and friends: the pass had nothing to do.
is_quiet() { ! printf '%s' "$1" | grep -Eq '[a-z_]+=[1-9]'; }

run_once() {
  local out summary ok=0

  out="$(post supplier-fulfil "{\"limit\":$LIMIT}")"
  summary="$(printf '%s' "$out" | summarise)"
  if [ -z "$summary" ] || [ "$summary" = "unreadable answer" ]; then
    log "supplier-fulfil: no answer (error, or a timeout)"
    ok=1
  elif ! is_quiet "$summary"; then
    log "supplier-fulfil: $summary"
  fi

  out="$(post telegram-dispatch '{}')"
  summary="$(printf '%s' "$out" | summarise)"
  if [ -z "$summary" ] || [ "$summary" = "unreadable answer" ]; then
    log "telegram-dispatch: no answer (error, or a timeout)"
    ok=1
  elif ! is_quiet "$summary"; then
    log "telegram-dispatch: $summary"
  fi

  return "$ok"
}

finish() {
  rm -f "$PIDFILE"
  exit 0
}
trap finish INT TERM

echo "$$" > "$PIDFILE"
log "watching every ${INTERVAL}s -> $FUNCTIONS_URL (stopped by --stop, or when the stack goes away)"

failures=0
while :; do
  if run_once; then
    failures=0
  else
    failures=$((failures + 1))
    log "worker call failed ($failures/5)"
    # `dev.sh` execs the app, so this process outlives the script that started
    # it. Five dead calls in a row means the stack is gone: stop rather than
    # leave a loop hammering a closed port.
    if [ "$failures" -ge 5 ]; then
      log "the stack looks down; stopping"
      finish
    fi
  fi

  [ "$ONCE" = "1" ] && finish
  sleep "$INTERVAL"
done
