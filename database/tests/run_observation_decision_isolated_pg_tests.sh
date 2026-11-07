#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SQL_FILE="$ROOT/database/tests/observation_decision_isolated_pg_test.sql"
test -f "$SQL_FILE"

DB_NAME="metra_obs_decision_test_$$"
export PGUSER="${PGUSER:-postgres}"
export PGHOST="${PGHOST:-/var/run/postgresql}"

cleanup() {
  psql -v ON_ERROR_STOP=1 -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" >/dev/null 2>&1 || true
}
trap cleanup EXIT

psql -v ON_ERROR_STOP=1 -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" >/dev/null
psql -v ON_ERROR_STOP=1 -d postgres -c "CREATE DATABASE ${DB_NAME};" >/dev/null

# Rewrite exception handlers to WHEN OTHERS for portability inside the temp DB run.
OUTPUT="$(psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" -f "$SQL_FILE" 2>&1)" || {
  echo "$OUTPUT" >&2
  echo "Isolated observation decision PostgreSQL tests FAILED." >&2
  exit 1
}

echo "$OUTPUT" | grep -q "OBSERVATION_DECISION_ISOLATED_PG_TESTS_PASSED"
echo "Isolated observation decision PostgreSQL tests passed."
