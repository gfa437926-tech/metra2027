#!/usr/bin/env bash
# Decrypt and import public/private schemas into an empty, explicitly identified target.
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF to the new project ref}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
DUMP_DIR="${1:?Usage: 03_import_schema.sh /path/to/export_stamp_dir}"
: "${METRA_TRANSFER_PASSPHRASE:?Set METRA_TRANSFER_PASSPHRASE in the secure shell environment}"

for forbidden_ref in tbdnklyxjvbrilvnwgmq nhovijnbtrocqahxxjou wdrcqceiagsmdxltqfwd vktcvkwqszehgmhqjrkb; do
  if [[ "$DST_REF" == "$forbidden_ref" ]]; then
    echo "Refusing: destination must be a new, non-legacy project." >&2
    exit 3
  fi
done
metra_assert_supabase_project_url "$DST_REF" "$DST_URL" "target"
command -v gpg >/dev/null 2>&1 || { echo "gpg is required." >&2; exit 4; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required." >&2; exit 4; }
[[ -s "$DUMP_DIR/SHA256SUMS" ]] || { echo "Missing SHA256SUMS manifest." >&2; exit 4; }
[[ -s "$DUMP_DIR/01_schema_application.sql.gpg" ]] || { echo "Missing encrypted public schema dump." >&2; exit 4; }

# Verify every artifact in the export before connecting to the destination.
(
  cd "$DUMP_DIR"
  sha256sum --check --strict SHA256SUMS
)

# Refuse to write into a target containing public/private application objects.
existing_objects="$(psql "$DST_URL" -X -v ON_ERROR_STOP=1 -At -c "
SELECT
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p','v','m','S','f'))
  +
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname IN ('public','private'))
  +
  (SELECT count(*) FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
   WHERE n.nspname IN ('public','private') AND t.typtype IN ('c','e','d','r'));
")"
if [[ "$existing_objects" != "0" ]]; then
  echo "Refusing: target public/private application schemas are not empty ($existing_objects application objects)." >&2
  exit 5
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
printf '%s\n' "$METRA_TRANSFER_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
  --passphrase-fd 0 --decrypt --output "$TMP_DIR/01_schema_application.sql" \
  "$DUMP_DIR/01_schema_application.sql.gpg"

echo "Importing public/private schemas into verified empty target $DST_REF"
psql "$DST_URL" -X -1 -v ON_ERROR_STOP=1 -f "$TMP_DIR/01_schema_application.sql"
echo "Schema import finished. Managed Auth schema/users are not imported by this script."
