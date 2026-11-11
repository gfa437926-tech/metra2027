#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
URL="${METRA_OPS_DATABASE_URL:-}"
if [ -z "$URL" ]; then
  echo "METRA_OPS_DATABASE_URL required" >&2
  exit 1
fi
psql "$URL" -v ON_ERROR_STOP=1 -f "$ROOT/database/tests/equipment_fault_npgsql_isolation.sql"
echo "equipment_fault_npgsql_isolation: all scenarios completed"
