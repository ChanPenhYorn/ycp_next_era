#!/usr/bin/env bash
#
# Runs the migrations and the money-logic test harness against a throwaway
# Postgres 16 container. Nothing but Docker is required.
#
#   supabase/tests/run.sh
#
set -euo pipefail

CONTAINER="${CONTAINER:-ycp-pg}"
DB="${DB:-ycp}"
PORT="${PORT:-55432}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running." >&2
  exit 1
fi

echo "==> starting $CONTAINER"
cleanup
docker run -d --name "$CONTAINER" \
  -e POSTGRES_PASSWORD=pg -e POSTGRES_DB="$DB" -p "$PORT:5432" postgres:16 >/dev/null

cleanup_on_fail() { echo "FAILED" >&2; cleanup; }
trap cleanup_on_fail ERR

for _ in $(seq 1 60); do
  docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done

psql_run() { docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 "$@"; }

echo "==> bootstrap (local-only Supabase stubs)"
psql_run -q < "$ROOT/supabase/tests/local_bootstrap.sql" 2>/dev/null

echo "==> migrations"
for migration in "$ROOT"/supabase/migrations/*.sql; do
  printf '    %s\n' "$(basename "$migration")"
  psql_run -q < "$migration"
done

echo "==> seed"
psql_run -q < "$ROOT/supabase/tests/seed_catalog.sql" >/dev/null

echo "==> smoke tests"
psql_run -f - < "$ROOT/supabase/tests/smoke.sql"

echo
echo "All checks passed. Leaving $CONTAINER running; 'docker rm -f $CONTAINER' to clean up."
