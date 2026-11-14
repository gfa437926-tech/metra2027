#!/usr/bin/env bash
# Runtime regression test for the read-only empty-target import guard.
# Run only against a disposable PostgreSQL database (the CI service database).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SQL="$ROOT/database/transfer/sql/assert_empty_application_tables.sql"
PSQL=(psql -X -v ON_ERROR_STOP=1)

command -v psql >/dev/null 2>&1 || {
  echo "FAIL: psql is required." >&2
  exit 2
}
[[ -s "$SQL" ]] || {
  echo "FAIL: missing empty-target guard SQL: $SQL" >&2
  exit 2
}

fixture="metra_empty_guard_fixture_$$"
cleanup() {
  "${PSQL[@]}" -c "DROP TABLE IF EXISTS public.$fixture" >/dev/null 2>&1 || true
  "${PSQL[@]}" -c "DROP TABLE IF EXISTS private.$fixture" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# The genuinely empty application schemas must pass.
"${PSQL[@]}" -f "$SQL"

# A row in public must be rejected.
"${PSQL[@]}" -c "CREATE TABLE public.$fixture (id integer PRIMARY KEY)"
"${PSQL[@]}" -c "INSERT INTO public.$fixture (id) VALUES (1)"
if "${PSQL[@]}" -f "$SQL" > /tmp/metra-empty-target-public.log 2>&1; then
  echo "FAIL: empty-target guard accepted a populated public table." >&2
  exit 1
fi
grep -F "public.$fixture is not empty" /tmp/metra-empty-target-public.log >/dev/null || {
  cat /tmp/metra-empty-target-public.log >&2
  echo "FAIL: public guard failed for an unexpected reason." >&2
  exit 1
}
"${PSQL[@]}" -c "DROP TABLE public.$fixture"

# A row in private must be rejected as well; the fixture schema is disposable.
"${PSQL[@]}" -c "CREATE SCHEMA IF NOT EXISTS private"
"${PSQL[@]}" -c "CREATE TABLE private.$fixture (id integer PRIMARY KEY)"
"${PSQL[@]}" -c "INSERT INTO private.$fixture (id) VALUES (1)"
if "${PSQL[@]}" -f "$SQL" > /tmp/metra-empty-target-private.log 2>&1; then
  echo "FAIL: empty-target guard accepted a populated private table." >&2
  exit 1
fi
grep -F "private.$fixture is not empty" /tmp/metra-empty-target-private.log >/dev/null || {
  cat /tmp/metra-empty-target-private.log >&2
  echo "FAIL: private guard failed for an unexpected reason." >&2
  exit 1
}

echo "PASS: empty public/private schemas accepted; populated public/private tables rejected."
