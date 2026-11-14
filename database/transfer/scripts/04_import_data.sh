#!/usr/bin/env bash
# Decrypt and import public/private data into empty tables on an identified target.
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
DUMP_DIR="${1:?Usage: 04_import_data.sh /path/to/export_stamp_dir}"
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
[[ -s "$DUMP_DIR/02_data_application.sql.gpg" ]] || { echo "Missing encrypted application data dump." >&2; exit 4; }

# Verify every artifact in the export before connecting to the destination.
(
  cd "$DUMP_DIR"
  sha256sum --check --strict SHA256SUMS
)
metra_verify_transfer_manifest "$DUMP_DIR"
AUTH_FK_INVENTORY="$DUMP_DIR/04_auth_user_fk_inventory.txt"
[[ -f "$AUTH_FK_INVENTORY" ]] || { echo "Missing Auth FK inventory." >&2; exit 4; }
[[ -s "$DUMP_DIR/07_extensions.txt" ]] || { echo "Missing required extension inventory." >&2; exit 4; }
target_extensions="$(psql "$DST_URL" -X -v ON_ERROR_STOP=1 -At -f "$SCRIPT_DIR/../sql/compare_extensions.sql")"
while IFS= read -r required_extension; do
  [[ -z "$required_extension" ]] && continue
  if ! grep -Fxq "$required_extension" <<< "$target_extensions"; then
    echo "Refusing data import: target is missing required extension/version/schema: $required_extension" >&2
    exit 6
  fi
done < "$DUMP_DIR/07_extensions.txt"


# Stop before writing if any target application table already contains rows.
psql "$DST_URL" -X -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/../sql/assert_empty_application_tables.sql"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
printf '%s\n' "$METRA_TRANSFER_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
  --passphrase-fd 0 --decrypt --output "$TMP_DIR/02_data_application.sql" \
  "$DUMP_DIR/02_data_application.sql.gpg"

metra_assert_no_excluded_observation_data "$TMP_DIR/02_data_application.sql"

echo "Importing public/private data into verified empty target $DST_REF"
psql "$DST_URL" -X -1 -v ON_ERROR_STOP=1 -f "$TMP_DIR/02_data_application.sql"
echo "Data import finished. Auth users are not imported by this script."
