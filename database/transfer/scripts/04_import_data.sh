#!/usr/bin/env bash
set -euo pipefail

DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
DUMP_DIR="${1:?Usage: 04_import_data.sh /path/to/export_stamp_dir}"

if [[ "$DST_REF" == "tbdnklyxjvbrilvnwgmq" ]]; then
  echo "Refusing: destination must be a different project."
  exit 3
fi

echo "Importing public data into $DST_REF"
psql "$DST_URL" -v ON_ERROR_STOP=1 -f "$DUMP_DIR/02_data_public.sql"
echo "Data import finished. Run comparison scripts."
