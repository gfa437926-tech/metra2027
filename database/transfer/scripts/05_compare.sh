#!/usr/bin/env bash
# Read-only exact comparison of public/private objects and row counts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
SRC_REF="${METRA_SRC_PROJECT_REF:-tbdnklyxjvbrilvnwgmq}"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF to the approved new project ref}"
SRC_URL="${METRA_SRC_DATABASE_URL:?Set METRA_SRC_DATABASE_URL}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${METRA_TRANSFER_OUT:-$ROOT/artifacts/compare-$(date -u +%Y%m%dT%H%M%SZ)}"

if [[ "$SRC_REF" != "tbdnklyxjvbrilvnwgmq" ]]; then
  echo "Refusing: source ref must be the approved experimental project." >&2
  exit 3
fi
if [[ "$DST_REF" == "$SRC_REF" || "$DST_REF" == "nhovijnbtrocqahxxjou" || "$DST_REF" == "wdrcqceiagsmdxltqfwd" || "$DST_REF" == "vktcvkwqszehgmhqjrkb" ]]; then
  echo "Refusing: target must be a distinct, non-legacy project." >&2
  exit 3
fi
metra_assert_supabase_project_url "$SRC_REF" "$SRC_URL" "source"
metra_assert_supabase_project_url "$DST_REF" "$DST_URL" "target"
command -v psql >/dev/null 2>&1 || { echo "psql is required." >&2; exit 4; }
command -v diff >/dev/null 2>&1 || { echo "diff is required." >&2; exit 4; }

mkdir -p "$OUT"
for side in source target; do
  if [[ "$side" == "source" ]]; then url="$SRC_URL"; else url="$DST_URL"; fi
  psql "$url" -X -v ON_ERROR_STOP=1 -At -F '|' \
    -f "$ROOT/sql/compare_rowcounts.sql" > "$OUT/${side}_rowcounts.txt"
  psql "$url" -X -v ON_ERROR_STOP=1 -At -F '|' \
    -f "$ROOT/sql/compare_objects.sql" > "$OUT/${side}_objects.txt"
  psql "$url" -X -v ON_ERROR_STOP=1 -At \
    -f "$ROOT/sql/compare_acl_inventory.sql" > "$OUT/${side}_acl.txt"
  psql "$url" -X -v ON_ERROR_STOP=1 -At \
    -f "$ROOT/sql/compare_extensions.sql" > "$OUT/${side}_extensions.txt"
done

set +e
diff -u "$OUT/source_rowcounts.txt" "$OUT/target_rowcounts.txt" > "$OUT/rowcounts.diff"
rows_status=$?
diff -u "$OUT/source_objects.txt" "$OUT/target_objects.txt" > "$OUT/objects.diff"
objects_status=$?
diff -u "$OUT/source_acl.txt" "$OUT/target_acl.txt" > "$OUT/acl.diff"
acl_status=$?
comm -23 <(sort "$OUT/source_extensions.txt") <(sort "$OUT/target_extensions.txt") > "$OUT/missing_extensions.diff"
if [[ -s "$OUT/missing_extensions.diff" ]]; then extension_status=1; else extension_status=0; fi
set -e

printf 'Source ref: %s\nTarget ref: %s\n' "$SRC_REF" "$DST_REF" > "$OUT/RESULT.txt"
if [[ "$rows_status" -eq 0 && "$objects_status" -eq 0 && "$acl_status" -eq 0 && "$extension_status" -eq 0 ]]; then
  echo "PASS: exact row counts, application objects, ACL inventories, and required extensions match." | tee -a "$OUT/RESULT.txt"
else
  echo "FAIL: differences detected; inspect rowcounts.diff, objects.diff, acl.diff, and missing_extensions.diff." | tee -a "$OUT/RESULT.txt"
  exit 1
fi

echo "Comparison artifacts: $OUT"
