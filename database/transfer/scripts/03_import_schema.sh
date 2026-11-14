#!/usr/bin/env bash
# Import public schema into an empty target. Requires prior owner approval.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF to the new project ref}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
DUMP_DIR="${1:?Usage: 03_import_schema.sh /path/to/export_stamp_dir}"

if [[ "$DST_REF" == "tbdnklyxjvbrilvnwgmq" || "$DST_REF" == "nhovijnbtrocqahxxjou" || "$DST_REF" == "wdrcqceiagsmdxltqfwd" || "$DST_REF" == "vktcvkwqszehgmhqjrkb" ]]; then
  echo "Refusing: destination must be a new, non-legacy project." >&2
  exit 3
fi
metra_assert_supabase_project_url "$DST_REF" "$DST_URL" "target"

if [[ ! -s "$DUMP_DIR/01_schema_public.sql" ]]; then
  echo "Missing or empty $DUMP_DIR/01_schema_public.sql" >&2
  exit 4
fi

echo "Importing public schema into explicitly identified target $DST_REF"
psql "$DST_URL" -X -v ON_ERROR_STOP=1 -c "SELECT current_database();"
psql "$DST_URL" -X -v ON_ERROR_STOP=1 -f "$DUMP_DIR/01_schema_public.sql"
echo "Schema import finished. Auth schema/users are not imported by this script."
