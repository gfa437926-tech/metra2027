#!/usr/bin/env bash
# Test the extension installer against a disposable PostgreSQL database.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORK_DIR="$(mktemp -d)"
DUMP_DIR="$WORK_DIR/export"
cleanup() {
  PGDATABASE=postgres dropdb --if-exists metra_extension_test >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
mkdir -p "$WORK_DIR/bin" "$DUMP_DIR"

cat > "$WORK_DIR/bin/psql" <<'WRAPPER'
#!/usr/bin/env bash
if [[ "${1:-}" == postgresql://* ]]; then
  shift
fi
exec /usr/bin/psql "$@"
WRAPPER
chmod 700 "$WORK_DIR/bin/psql"
export PATH="$WORK_DIR/bin:$PATH"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
createdb metra_extension_test
export PGDATABASE=metra_extension_test

export METRA_DST_PROJECT_REF="newmetratarget12345678"
export METRA_DST_DATABASE_URL="postgresql://postgres:ci-secret@db.newmetratarget12345678.supabase.co:5432/metra_extension_test"

cat > "$DUMP_DIR/07_extensions.txt" <<'EXTENSIONS'
plpgsql|1.0|pg_catalog
pgcrypto|1.3|public
EXTENSIONS
cat > "$DUMP_DIR/MANIFEST.txt" <<'MANIFEST'
source_project_ref=tbdnklyxjvbrilvnwgmq
auth_users_exported=false
auth_user_count=0
auth_user_fk_inventory_exported=true
observation_provenance_exported=true
observation_records_data_exported=false
all_observation_records_excluded=true
demo_observation_records_excluded=true
non_demo_observation_records_excluded=true
runtime_role_inventory_exported=true
required_extensions_inventory_exported=true
station_catalogue_provenance_exported=true
api_keys_and_jwt_secrets_exported=false
MANIFEST

# The installer verifies the complete transfer artifact set, not just the extension
# inventory. Supply every required artifact so the fixture tests that contract.
for file in \
  01_schema_application.sql.gpg \
  02_data_application.sql.gpg \
  03_inventory_tables.txt \
  03_inventory_functions.txt \
  04_auth_user_fk_inventory.txt \
  05_observation_provenance.txt \
  06_runtime_role_inventory.txt \
  08_station_catalogue_provenance.txt; do
  printf 'fixture:%s\n' "$file" > "$DUMP_DIR/$file"
done

write_checksums() {
  (
    cd "$DUMP_DIR"
    sha256sum \
      01_schema_application.sql.gpg \
      02_data_application.sql.gpg \
      03_inventory_tables.txt \
      03_inventory_functions.txt \
      04_auth_user_fk_inventory.txt \
      05_observation_provenance.txt \
      06_runtime_role_inventory.txt \
      07_extensions.txt \
      08_station_catalogue_provenance.txt \
      MANIFEST.txt > SHA256SUMS
  )
}
write_checksums

# An extension already installed in the wrong schema must be rejected, not silently accepted.
psql -X -v ON_ERROR_STOP=1 -c "CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions;"
if bash "$ROOT/database/transfer/scripts/02_install_required_extensions.sh" "$DUMP_DIR"; then
  echo "Installer accepted pgcrypto in a schema different from the source inventory." >&2
  exit 1
fi
psql -X -v ON_ERROR_STOP=1 -c "DROP EXTENSION pgcrypto;"

# Correct source schema: installer creates the extension and a second run is idempotent.
sed -i 's/^pgcrypto|1.3|public$/pgcrypto|1.3|extensions/' "$DUMP_DIR/07_extensions.txt"
write_checksums
bash "$ROOT/database/transfer/scripts/02_install_required_extensions.sh" "$DUMP_DIR"
bash "$ROOT/database/transfer/scripts/02_install_required_extensions.sh" "$DUMP_DIR"

installed_schema="$(psql -X -At -c "SELECT n.nspname FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='pgcrypto'")"
installed_version="$(psql -X -At -c "SELECT extversion FROM pg_extension WHERE extname='pgcrypto'")"
[[ "$installed_schema" == "extensions" ]] || { echo "pgcrypto was installed in the wrong schema." >&2; exit 1; }
[[ "$installed_version" == "1.3" ]] || { echo "Unexpected pgcrypto version: $installed_version" >&2; exit 1; }

echo "PASS: required extensions install idempotently with matching schema and version."
