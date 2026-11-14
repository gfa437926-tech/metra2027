#!/usr/bin/env bash
# Runtime regression for the policy that observation history is never copied.
# Run only against the disposable PostgreSQL service used by CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SQL="$ROOT/database/transfer/sql/compare_excluded_data.sql"
PSQL=(psql -X -v ON_ERROR_STOP=1 -At)

command -v psql >/dev/null 2>&1 || {
  echo "FAIL: psql is required." >&2
  exit 2
}
[[ -s "$SQL" ]] || {
  echo "FAIL: missing excluded-data comparison SQL: $SQL" >&2
  exit 2
}

cleanup() {
  "${PSQL[@]}" -c "DROP TABLE IF EXISTS public.metra_observation_records" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${PSQL[@]}" -c "CREATE TABLE public.metra_observation_records (id bigint PRIMARY KEY)"
empty_count="$("${PSQL[@]}" -f "$SQL" | tr -d '\r\n')"
[[ "$empty_count" == "0" ]] || {
  echo "FAIL: empty excluded-history fixture returned '$empty_count', expected 0." >&2
  exit 1
}

"${PSQL[@]}" -c "INSERT INTO public.metra_observation_records (id) VALUES (1)"
populated_count="$("${PSQL[@]}" -f "$SQL" | tr -d '\r\n')"
[[ "$populated_count" == "1" ]] || {
  echo "FAIL: populated excluded-history fixture returned '$populated_count', expected 1." >&2
  exit 1
}

echo "PASS: excluded observation history is counted independently and reports non-empty targets."
