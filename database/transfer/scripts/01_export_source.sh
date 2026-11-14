#!/usr/bin/env bash
# Export experimental source dump (schema + data). Never deletes source.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
SRC_REF="${METRA_SRC_PROJECT_REF:-tbdnklyxjvbrilvnwgmq}"
SRC_URL="${METRA_SRC_DATABASE_URL:?Set METRA_SRC_DATABASE_URL}"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${METRA_TRANSFER_OUT:-$ROOT/database/transfer/artifacts/$STAMP}"

if [[ "$SRC_REF" != "tbdnklyxjvbrilvnwgmq" ]]; then
  echo "Refusing: only the approved experimental source project is allowed." >&2
  exit 3
fi
metra_assert_supabase_project_url "$SRC_REF" "$SRC_URL" "source"
mkdir -p "$OUT_DIR"

echo "Exporting approved source $SRC_REF → $OUT_DIR"

pg_dump "$SRC_URL" --format=plain --schema-only --no-owner --no-privileges \
  --schema=public --file="$OUT_DIR/01_schema_public.sql"

# Supabase-managed Auth schema export is not a supported/verified part of this pack.
echo "NOTICE: Auth users/identities are NOT exported by this script."

pg_dump "$SRC_URL" --format=plain --data-only --no-owner --disable-triggers \
  --schema=public --file="$OUT_DIR/02_data_public.sql"

psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_tables.txt" -c "\
SELECT table_schema, table_name FROM information_schema.tables \
WHERE table_schema IN ('public','private') ORDER BY 1,2;"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_functions.txt" -c "\
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) \
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace \
WHERE n.nspname IN ('public','private') ORDER BY 1,2,3;"

(
  cd "$OUT_DIR"
  sha256sum 01_schema_public.sql 02_data_public.sql 03_inventory_tables.txt 03_inventory_functions.txt > SHA256SUMS
)

{
  echo "source_project_ref=$SRC_REF"
  echo "exported_at_utc=$STAMP"
  echo "host_tool=$(pg_dump --version | head -1)"
  echo "auth_users_exported=false"
  echo "api_keys_and_jwt_secrets_exported=false"
} > "$OUT_DIR/MANIFEST.txt"

echo "Export complete: $OUT_DIR"
echo "Keep this directory offline; do not commit dumps to git."
