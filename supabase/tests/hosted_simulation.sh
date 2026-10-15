#!/usr/bin/env bash
#
# Applies the migrations against a cron schema that REFUSES direct DML, the way
# hosted Supabase does. Reproduces:
#
#   ERROR 42501: permission denied for table job
#
# and proves the fix: scheduling degrades to a notice, the schema still lands.
#
#   supabase/tests/hosted_simulation.sh
#
set -euo pipefail

CONTAINER="${CONTAINER:-ycp-hosted}"
DB="${DB:-h}"
PORT="${PORT:-55435}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

command -v docker >/dev/null 2>&1 || { echo "docker required"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker is not running." >&2; exit 1; }

cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "==> starting $CONTAINER"
cleanup
docker run -d --name "$CONTAINER" \
  -e POSTGRES_PASSWORD=pg -e POSTGRES_DB="$DB" -p "$PORT:5432" postgres:16 >/dev/null

for _ in $(seq 1 60); do
  docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done

P() { docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 "$@"; }

echo "==> bootstrap + hostile cron schema"
P -q < "$ROOT/supabase/tests/local_bootstrap.sql" 2>/dev/null
P -q < "$ROOT/supabase/tests/hosted_cron_stub.sql"

echo "==> migrations (must not abort on cron permission denial)"
for migration in "$ROOT"/supabase/migrations/*.sql; do
  printf '    %s\n' "$(basename "$migration")"
  P -q < "$migration"
done

echo "==> schema present?"
tables=$(P -t -A -c "select count(*) from pg_tables where schemaname='public'")
echo "    public tables: $tables"
[ "$tables" -ge 15 ] || { echo "    FAIL: expected the full schema"; exit 1; }

echo "==> fixtures (seed_catalog, not demo: the smoke suite depends on it)"
P -q < "$ROOT/supabase/tests/seed_catalog.sql" >/dev/null

echo "==> assertions"
P -f - < "$ROOT/supabase/tests/smoke.sql" > /tmp/hosted-sim.log 2>&1 || true
passes=$(grep -oE "PASS \[[^]]+\]" /tmp/hosted-sim.log | wc -l | tr -d ' ')
fails=$(grep -c "FAIL" /tmp/hosted-sim.log || true)
echo "    $passes passed, $fails failed"
[ "$fails" -eq 0 ] || { echo "    FAIL"; exit 1; }

echo
echo "OK: a cron schema that refuses DML no longer takes the schema down with it."
