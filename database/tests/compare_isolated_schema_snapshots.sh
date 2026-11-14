#!/usr/bin/env bash
# Compare schema-only snapshots from TWO already-restored isolated PostgreSQL databases.
# This script is read-only. It does not create databases or apply migrations.
set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <isolated-db-a-url> <isolated-db-b-url>" >&2
  exit 64
fi
command -v psql >/dev/null || { echo "psql is required" >&2; exit 69; }
command -v pg_dump >/dev/null || { echo "pg_dump is required" >&2; exit 69; }
command -v diff >/dev/null || { echo "diff is required" >&2; exit 69; }

DB_A="$1"
DB_B="$2"
[[ "$DB_A" != "$DB_B" ]] || { echo "Refusing identical connection URLs" >&2; exit 64; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Capture identity without printing credentials or full connection strings.
psql "$DB_A" -X -v ON_ERROR_STOP=1 -Atc \
  "select current_database() || '|' || coalesce(inet_server_addr()::text,'local') || '|' || coalesce(inet_server_port()::text,'local')" \
  > "$TMP_DIR/a.identity"
psql "$DB_B" -X -v ON_ERROR_STOP=1 -Atc \
  "select current_database() || '|' || coalesce(inet_server_addr()::text,'local') || '|' || coalesce(inet_server_port()::text,'local')" \
  > "$TMP_DIR/b.identity"

if [[ "$(cat "$TMP_DIR/a.identity")" == "$(cat "$TMP_DIR/b.identity")" ]]; then
  echo "Refusing: both URLs resolve to the same database endpoint." >&2
  exit 65
fi

pg_dump "$DB_A" --schema-only --no-owner --no-privileges --quote-all-identifiers \
  --file="$TMP_DIR/a.schema.sql"
pg_dump "$DB_B" --schema-only --no-owner --no-privileges --quote-all-identifiers \
  --file="$TMP_DIR/b.schema.sql"

if diff -u "$TMP_DIR/a.schema.sql" "$TMP_DIR/b.schema.sql"; then
  echo "PASS: schema-only snapshots are identical."
else
  echo "FAIL: schema-only snapshots differ; inspect diff above." >&2
  exit 1
fi

# Include catalog-level details (RLS, policies, triggers, routines, constraints)
# in the same run for review. Output is intentionally local and may contain schema metadata.
psql "$DB_A" -X -v ON_ERROR_STOP=1 -f database/baseline/verify_full_schema_catalog.sql \
  > full-schema-catalog-a.txt
psql "$DB_B" -X -v ON_ERROR_STOP=1 -f database/baseline/verify_full_schema_catalog.sql \
  > full-schema-catalog-b.txt
if diff -u full-schema-catalog-a.txt full-schema-catalog-b.txt; then
  echo "PASS: detailed catalog inventories are identical."
else
  echo "FAIL: detailed catalog inventories differ." >&2
  exit 1
fi
