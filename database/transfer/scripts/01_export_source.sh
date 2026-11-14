#!/usr/bin/env bash
# Encrypted export of public schema/data from the approved experimental source.
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
SRC_REF="${METRA_SRC_PROJECT_REF:-tbdnklyxjvbrilvnwgmq}"
SRC_URL="${METRA_SRC_DATABASE_URL:?Set METRA_SRC_DATABASE_URL}"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${METRA_TRANSFER_OUT:-$ROOT/database/transfer/artifacts/$STAMP}"
: "${METRA_TRANSFER_PASSPHRASE:?Set METRA_TRANSFER_PASSPHRASE in the secure shell environment}"

if [[ "$SRC_REF" != "tbdnklyxjvbrilvnwgmq" ]]; then
  echo "Refusing: only the approved experimental source project is allowed." >&2
  exit 3
fi
metra_assert_supabase_project_url "$SRC_REF" "$SRC_URL" "source"
command -v pg_dump >/dev/null 2>&1 || { echo "pg_dump is required." >&2; exit 4; }
command -v psql >/dev/null 2>&1 || { echo "psql is required." >&2; exit 4; }
command -v gpg >/dev/null 2>&1 || { echo "gpg is required for encrypted exports." >&2; exit 4; }

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Exporting approved source $SRC_REF to encrypted artifacts."
pg_dump "$SRC_URL" --format=plain --schema-only --no-owner --no-privileges \
  --schema=public --file="$TMP_DIR/01_schema_public.sql"
pg_dump "$SRC_URL" --format=plain --data-only --no-owner --disable-triggers \
  --schema=public --file="$TMP_DIR/02_data_public.sql"

for dump in 01_schema_public.sql 02_data_public.sql; do
  printf '%s\n' "$METRA_TRANSFER_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
    --passphrase-fd 0 --symmetric --cipher-algo AES256 \
    --output "$OUT_DIR/$dump.gpg" "$TMP_DIR/$dump"
done

psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_tables.txt" -c "\
SELECT table_schema, table_name FROM information_schema.tables \
WHERE table_schema IN ('public','private') ORDER BY 1,2;"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/03_inventory_functions.txt" -c "\
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) \
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace \
WHERE n.nspname = 'public' ORDER BY 1,2,3;"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -o "$OUT_DIR/04_auth_user_fk_inventory.txt" -c "\
SELECT n.nspname, c.relname, con.conname, pg_get_constraintdef(con.oid) \
FROM pg_constraint con \
JOIN pg_class c ON c.oid = con.conrelid \
JOIN pg_namespace n ON n.oid = c.relnamespace \
WHERE con.contype = 'f' AND con.confrelid = 'auth.users'::regclass \
ORDER BY 1,2,3;"

(
  cd "$OUT_DIR"
  sha256sum 01_schema_public.sql.gpg 02_data_public.sql.gpg 03_inventory_tables.txt 03_inventory_functions.txt 04_auth_user_fk_inventory.txt > SHA256SUMS
)

{
  echo "source_project_ref=$SRC_REF"
  echo "exported_at_utc=$STAMP"
  echo "host_tool=$(pg_dump --version | head -1)"
  echo "encryption=gpg-symmetric-AES256"
  echo "auth_users_exported=false"
  echo "api_keys_and_jwt_secrets_exported=false"
} > "$OUT_DIR/MANIFEST.txt"

echo "Encrypted export complete: $OUT_DIR"
echo "Plaintext temporary dumps were removed on exit. Keep the passphrase separately."
