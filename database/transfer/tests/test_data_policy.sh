#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/project_url_guard.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf '%s\n' 'COPY public.station_catalogue (id) FROM stdin;' > "$TMP_DIR/allowed.sql"
metra_assert_no_excluded_observation_data "$TMP_DIR/allowed.sql"

printf '%s\n' 'COPY public.metra_observation_records (id) FROM stdin;' > "$TMP_DIR/blocked.sql"
if metra_assert_no_excluded_observation_data "$TMP_DIR/blocked.sql"; then
  echo "FAIL: excluded observation data was accepted." >&2
  exit 1
fi

echo "PASS: excluded observation data dump guard."
