#!/usr/bin/env bash
# Import public data into the explicitly identified target.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
DUMP_DIR="${1:?Usage: 04_import_data.sh /path/to/export_stamp_dir}"

if [[ "$DST_REF" == "tbdnklyxjvbrilvnwgmq" || "$DST_REF" == "nhovijnbtrocqahxxjou" || "$DST_REF" == "wdrcqceiagsmdxltqfwd" || "$DST_REF" == "vktcvkwqszehgmhqjrkb" ]]; then
  echo "Refusing: destination must be a new, non-legacy project." >&2
  exit 3
fi
metra_assert_supabase_project_url "$DST_REF" "$DST_URL" "target"

if [[ ! -s "$DUMP_DIR/02_data_public.sql" ]]; then
  echo "Missing or empty $DUMP_DIR/02_data_public.sql" >&2
  exit 4
fi

echo "Importing public data into explicitly identified target $DST_REF"
psql "$DST_URL" -X -v ON_ERROR_STOP=1 -f "$DUMP_DIR/02_data_public.sql"
echo "Data import finished. Auth users are not imported by this script."
