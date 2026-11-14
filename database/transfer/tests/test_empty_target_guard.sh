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
}
trap cleanup EXIT

# A truly empty application schema must pass.
"${PSQL[@]}" -f "$SQL"

# A single row in an application table must make the same guard fail closed.
"${PSQL[@]}" -c "CREATE TABLE public.$fixture (id integer PRIMARY KEY)"
"${PSQL[@]}" -c "INSERT INTO public.$fixture (id) VALUES (1)"

if "${PSQL[@]}" -f "$SQL" > /tmp/metra-empty-target-guard.log 2>&1; then
  echo "FAIL: empty-target guard accepted a populated application table." >&2
  exit 1
fi

grep -F "is not empty" /tmp/metra-empty-target-guard.log >/dev/null || {
  cat /tmp/metra-empty-target-guard.log >&2
  echo "FAIL: guard failed for an unexpected reason." >&2
  exit 1
}

echo "PASS: empty application schema accepted; populated application table rejected."
