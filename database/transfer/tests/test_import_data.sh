#!/usr/bin/env bash
# Exercise the actual data-import script against an isolated local PostgreSQL fixture.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORK_DIR="$(mktemp -d)"
DUMP_DIR="$WORK_DIR/export"
cleanup() {
  PGDATABASE=postgres dropdb --if-exists metra_import_test >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
mkdir -p "$WORK_DIR/bin" "$DUMP_DIR"

createdb metra_import_test
export PGDATABASE=metra_import_test

# The importer validates a Supabase URL; this test wrapper maps that validated
# URL to the disposable local PostgreSQL service without changing importer code.
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
export PGDATABASE="${PGDATABASE:-postgres}"

export METRA_DST_PROJECT_REF="newmetratarget12345678"
export METRA_DST_DATABASE_URL="postgresql://postgres:ci-secret@db.newmetratarget12345678.supabase.co:5432/postgres"
export METRA_TRANSFER_PASSPHRASE="ci-only-transfer-passphrase"

# Supabase-like target prerequisites and one empty application table.
psql -X -v ON_ERROR_STOP=1 <<'SQL'
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users(id uuid PRIMARY KEY);
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE IF NOT EXISTS public.import_fixture(id integer PRIMARY KEY, note text NOT NULL);
TRUNCATE TABLE public.import_fixture;
SQL

: > "$DUMP_DIR/01_schema_application.sql.gpg"
: > "$DUMP_DIR/03_inventory_tables.txt"
: > "$DUMP_DIR/03_inventory_functions.txt"
: > "$DUMP_DIR/04_auth_user_fk_inventory.txt"
: > "$DUMP_DIR/05_observation_provenance.txt"
: > "$DUMP_DIR/06_runtime_role_inventory.txt"
: > "$DUMP_DIR/08_station_catalogue_provenance.txt"
psql -X -v ON_ERROR_STOP=1 -At -f "$ROOT/database/transfer/sql/compare_extensions.sql" \
  > "$DUMP_DIR/07_extensions.txt"

cat > "$DUMP_DIR/MANIFEST.txt" <<'MANIFEST'
source_project_ref=tbdnklyxjvbrilvnwgmq
auth_users_exported=false
auth_user_count=0
auth_user_fk_inventory_exported=true
observation_provenance_exported=true
observation_records_data_exported=false
non_demo_observation_records_excluded=true
runtime_role_inventory_exported=true
required_extensions_inventory_exported=true
station_catalogue_provenance_exported=true
api_keys_and_jwt_secrets_exported=false
MANIFEST

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

cat > "$WORK_DIR/data.sql" <<'DATA'
COPY public.import_fixture (id, note) FROM stdin;
1	imported row
\.
DATA
printf '%s\n' "$METRA_TRANSFER_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
  --passphrase-fd 0 --symmetric --cipher-algo AES256 \
  --output "$DUMP_DIR/02_data_application.sql.gpg" "$WORK_DIR/data.sql"
write_checksums

bash "$ROOT/database/transfer/scripts/04_import_data.sh" "$DUMP_DIR"
imported_count="$(psql -X -At -c "SELECT count(*) FROM public.import_fixture WHERE id=1 AND note='imported row'")"
[[ "$imported_count" == "1" ]] || { echo "Expected the fixture row to be imported." >&2; exit 1; }

# A dump that contains the deliberately excluded observation table must fail
# before importing any application data.
psql -X -v ON_ERROR_STOP=1 -c "TRUNCATE TABLE public.import_fixture;"
cat > "$WORK_DIR/data-excluded.sql" <<'DATA'
COPY public.metra_observation_records (id) FROM stdin;
1
\.
DATA
printf '%s\n' "$METRA_TRANSFER_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
  --passphrase-fd 0 --symmetric --cipher-algo AES256 \
  --output "$DUMP_DIR/02_data_application.sql.gpg" "$WORK_DIR/data-excluded.sql"
write_checksums
if bash "$ROOT/database/transfer/scripts/04_import_data.sh" "$DUMP_DIR"; then
  echo "Expected importer to reject excluded observation-history data." >&2
  exit 1
fi
remaining_count="$(psql -X -At -c "SELECT count(*) FROM public.import_fixture")"
[[ "$remaining_count" == "0" ]] || { echo "Excluded-data rejection wrote application rows." >&2; exit 1; }

echo "PASS: data importer verifies the archive, imports a valid fixture, and blocks excluded observation data."
