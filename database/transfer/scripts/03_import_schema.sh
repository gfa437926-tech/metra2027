#!/usr/bin/env bash
# Import schema into EMPTY target. Requires prior owner approval.
set -euo pipefail

DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF to the new project ref}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
DUMP_DIR="${1:?Usage: 03_import_schema.sh /path/to/export_stamp_dir}"

if [[ "$DST_REF" == "tbdnklyxjvbrilvnwgmq" ]]; then
  echo "Refusing: destination ref must not equal experimental source ref."
  exit 3
fi

echo "Importing schema into target project $DST_REF"
psql "$DST_URL" -v ON_ERROR_STOP=1 -c "SELECT current_database();"

if [[ -f "$DUMP_DIR/01_schema_public.sql" ]]; then
  psql "$DST_URL" -v ON_ERROR_STOP=1 -f "$DUMP_DIR/01_schema_public.sql"
else
  echo "Missing $DUMP_DIR/01_schema_public.sql"
  exit 4
fi

echo "Schema import finished. Run 04_import_data.sh next."
