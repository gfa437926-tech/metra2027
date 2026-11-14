#!/usr/bin/env bash
# Read-only preflight for the one approved METRA experimental source project.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"

SRC_REF="${METRA_SRC_PROJECT_REF:-tbdnklyxjvbrilvnwgmq}"
SRC_URL="${METRA_SRC_DATABASE_URL:-}"

if [[ "$SRC_REF" != "tbdnklyxjvbrilvnwgmq" ]]; then
  echo "Refusing: only the approved experimental source project is allowed." >&2
  exit 3
fi
if [[ -z "$SRC_URL" ]]; then
  echo "METRA_SRC_DATABASE_URL is not set." >&2
  exit 2
fi
metra_assert_supabase_project_url "$SRC_REF" "$SRC_URL" "source"

for forbidden_ref in nhovijnbtrocqahxxjou wdrcqceiagsmdxltqfwd vktcvkwqszehgmhqjrkb; do
  if [[ "$SRC_URL" == *"$forbidden_ref"* ]]; then
    echo "Refusing connection: URL contains a forbidden legacy METRA project ref." >&2
    exit 3
  fi
done

command -v psql >/dev/null 2>&1 || { echo "psql is required." >&2; exit 4; }
command -v pg_dump >/dev/null 2>&1 || { echo "pg_dump is required." >&2; exit 4; }

echo "Probing approved source (read-only)..."
SERVER_VERSION_NUM="$(psql "$SRC_URL" -X -At -v ON_ERROR_STOP=1 -c "SHOW server_version_num")"
metra_assert_pg_dump_compatible "$SERVER_VERSION_NUM" "$(pg_dump --version)"
echo "PostgreSQL server major: $((SERVER_VERSION_NUM / 10000)); pg_dump: $(pg_dump --version)"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 -c "SELECT current_database() AS db, current_user AS usr;"
psql "$SRC_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
SELECT
  (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public') AS public_tables,
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public') AS public_functions;
SQL

echo "Preflight OK: URL identity matches approved source ref $SRC_REF."
