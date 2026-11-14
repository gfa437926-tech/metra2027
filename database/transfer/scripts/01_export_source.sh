#!/usr/bin/env bash
# Export experimental source dump (schema + data). Never deletes source.
set -euo pipefail

SRC_REF="${METRA_SRC_PROJECT_REF:-tbdnklyxjvbrilvnwgmq}"
SRC_URL="${METRA_SRC_DATABASE_URL:?Set METRA_SRC_DATABASE_URL}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${METRA_TRANSFER_OUT:-$ROOT/database/transfer/artifacts/$STAMP}"
mkdir -p "$OUT_DIR"

echo "Exporting source $SRC_REF → $OUT_DIR"

pg_dump "$SRC_URL" \
  --format=plain \
  --schema-only \
  --no-owner \
  --no-privileges \
  --schema=public \
  --file="$OUT_DIR/01_schema_public.sql"

pg_dump "$SRC_URL" \
  --format=plain \
  --schema-only \
  --no-owner \
  --no-privileges \
  --schema=auth \
  --file="$OUT_DIR/01_schema_auth.sql" || {
    echo "WARN: auth schema dump skipped or failed (permissions)."
  }

pg_dump "$SRC_URL" \
  --format=plain \
  --data-only \
  --no-owner \
  --disable-triggers \
  --schema=public \
  --file="$OUT_DIR/02_data_public.sql"

psql "$SRC_URL" -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_tables.txt" -c "\
SELECT table_schema, table_name FROM information_schema.tables \
WHERE table_schema IN ('public','auth') ORDER BY 1,2;"

psql "$SRC_URL" -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_rowcounts.txt" -c "\
SELECT schemaname, relname AS table_name, n_live_tup AS approx_rows \
FROM pg_stat_user_tables ORDER BY schemaname, relname;"

psql "$SRC_URL" -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_functions.txt" -c "\
SELECT n.nspname, p.proname FROM pg_proc p \
JOIN pg_namespace n ON n.oid = p.pronamespace \
WHERE n.nspname IN ('public','private') ORDER BY 1,2;"

{
  echo "source_project_ref=$SRC_REF"
  echo "exported_at_utc=$STAMP"
  echo "host_tool=$(pg_dump --version | head -1)"
  echo "note=API keys and JWT secrets are NOT included"
} > "$OUT_DIR/MANIFEST.txt"

echo "Export complete: $OUT_DIR"
echo "Keep this directory offline; do not commit dumps to git."
