#!/usr/bin/env bash
# Reapply reviewed application runtime grants after schema import.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"

for forbidden_ref in tbdnklyxjvbrilvnwgmq nhovijnbtrocqahxxjou wdrcqceiagsmdxltqfwd vktcvkwqszehgmhqjrkb; do
  if [[ "$DST_REF" == "$forbidden_ref" ]]; then
    echo "Refusing: grants cannot be applied to source or legacy projects." >&2
    exit 3
  fi
done
metra_assert_supabase_project_url "$DST_REF" "$DST_URL" "target"
psql "$DST_URL" -X -1 -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/../sql/apply_runtime_grants.sql"
echo "Reviewed metra_api_runtime grants applied to $DST_REF."
