#!/usr/bin/env bash
# Bootstrap the non-login runtime role before importing schema objects/policies.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"

for forbidden_ref in tbdnklyxjvbrilvnwgmq nhovijnbtrocqahxxjou wdrcqceiagsmdxltqfwd vktcvkwqszehgmhqjrkb; do
  if [[ "$DST_REF" == "$forbidden_ref" ]]; then
    echo "Refusing: target must be a new, non-legacy Supabase project." >&2
    exit 3
  fi
done
metra_assert_supabase_project_url "$DST_REF" "$DST_URL" "target"
psql "$DST_URL" -X -1 -v ON_ERROR_STOP=1 -f "$SCRIPT_DIR/../sql/bootstrap_target_roles.sql"
echo "Target role bootstrap complete for $DST_REF."
