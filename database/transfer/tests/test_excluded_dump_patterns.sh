#!/usr/bin/env bash
# Verify every supported pg_dump spelling of excluded observation data is blocked.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT_DIR="$ROOT/database/transfer/scripts"
WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

source "$SCRIPT_DIR/lib/project_url_guard.sh"

patterns=(
  'COPY public.metra_observation_records'
  'COPY "public"."metra_observation_records"'
  'INSERT INTO public.metra_observation_records'
  'INSERT INTO "public"."metra_observation_records"'
)

index=0
for pattern in "${patterns[@]}"; do
  index=$((index + 1))
  dump="$WORK_DIR/excluded-$index.sql"
  printf '%s\n' "$pattern (id) FROM stdin;" > "$dump"
  if metra_assert_no_excluded_observation_data "$dump"; then
    echo "FAIL: excluded dump syntax was accepted: $pattern" >&2
    exit 1
  fi
done

# Similar names and unrelated application tables must not be false positives.
allowed_dump="$WORK_DIR/allowed.sql"
cat > "$allowed_dump" <<'SQL'
COPY public.metra_observation_records_archive (id) FROM stdin;
1
\.
INSERT INTO public.metra_observation_summary (id) VALUES (1);
SQL
metra_assert_no_excluded_observation_data "$allowed_dump"

if metra_assert_no_excluded_observation_data "$WORK_DIR/missing.sql"; then
  echo "FAIL: missing dump file was accepted." >&2
  exit 1
fi

: > "$WORK_DIR/empty.sql"
if metra_assert_no_excluded_observation_data "$WORK_DIR/empty.sql"; then
  echo "FAIL: empty dump file was accepted." >&2
  exit 1
fi

echo "PASS: all supported excluded-history dump forms are rejected without false positives."
