#!/usr/bin/env bash
# Read-only preflight for METRA experimental source project.
set -euo pipefail

SRC_REF="${METRA_SRC_PROJECT_REF:-tbdnklyxjvbrilvnwgmq}"
SRC_URL="${METRA_SRC_DATABASE_URL:-}"

echo "== METRA transfer preflight =="
echo "Expected source project ref: $SRC_REF"

if [[ -z "$SRC_URL" ]]; then
  echo "METRA_SRC_DATABASE_URL is not set."
  echo "Set it to the Postgres connection string of project $SRC_REF only."
  echo "Do not point this variable at any legacy METRA database."
  exit 2
fi

if echo "$SRC_URL" | grep -qiE 'vktcvkwqszehgmhqjrkb'; then
  echo "Refusing connection: URL looks like a forbidden legacy project."
  exit 3
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required for transfer scripts."
  exit 4
fi
if ! command -v pg_dump >/dev/null 2>&1; then
  echo "pg_dump is required for transfer scripts."
  exit 4
fi

echo "Probing source (read-only)..."
psql "$SRC_URL" -v ON_ERROR_STOP=1 -c "SELECT current_database() AS db, current_user AS usr;"

psql "$SRC_URL" -v ON_ERROR_STOP=1 <<'SQL'
SELECT
  (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public') AS public_tables,
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public') AS public_functions;
SQL

echo "Preflight OK. Confirm manually that this database belongs to project ref: $SRC_REF"
echo "Open https://${SRC_REF}.supabase.co in the dashboard and match DB size / table counts before export."
