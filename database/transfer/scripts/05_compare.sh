#!/usr/bin/env bash
# Read-only exact comparison of public/private objects and row counts.
set -euo pipefail

SRC_REF="${METRA_SRC_PROJECT_REF:-tbdnklyxjvbrilvnwgmq}"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF to the approved new project ref}"
SRC_URL="${METRA_SRC_DATABASE_URL:?Set METRA_SRC_DATABASE_URL}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${METRA_TRANSFER_OUT:-$ROOT/artifacts/compare-$(date -u +%Y%m%dT%H%M%SZ)}"

if [[ "$SRC_REF" != "tbdnklyxjvbrilvnwgmq" ]]; then
  echo "Refusing: source ref must be the approved experimental project." >&2
  exit 3
fi
if [[ "$DST_REF" == "$SRC_REF" ]]; then
  echo "Refusing: source and target refs must differ." >&2
  exit 3
fi
if [[ "$DST_REF" == "nhovijnbtrocqahxxjou" || "$DST_REF" == "wdrcqceiagsmdxltqfwd" || "$DST_REF" == "vktcvkwqszehgmhqjrkb" ]]; then
  echo "Refusing: target ref is a forbidden legacy METRA project." >&2
  exit 3
fi
if ! command -v psql >/dev/null 2>&1 || ! command -v diff >/dev/null 2>&1; then
  echo "psql and diff are required." >&2
  exit 4
fi

mkdir -p "$OUT"
for side in source target; do
  if [[ "$side" == "source" ]]; then url="$SRC_URL"; else url="$DST_URL"; fi
  psql "$url" -X -v ON_ERROR_STOP=1 -At -F '|' \
    -f "$ROOT/sql/compare_rowcounts.sql" > "$OUT/${side}_rowcounts.txt"
  psql "$url" -X -v ON_ERROR_STOP=1 -At -F '|' \
    -f "$ROOT/sql/compare_objects.sql" > "$OUT/${side}_objects.txt"
done

set +e
diff -u "$OUT/source_rowcounts.txt" "$OUT/target_rowcounts.txt" > "$OUT/rowcounts.diff"
rows_status=$?
diff -u "$OUT/source_objects.txt" "$OUT/target_objects.txt" > "$OUT/objects.diff"
objects_status=$?
set -e

printf 'Source ref: %s\nTarget ref: %s\n' "$SRC_REF" "$DST_REF" > "$OUT/RESULT.txt"
if [[ "$rows_status" -eq 0 && "$objects_status" -eq 0 ]]; then
  echo "PASS: exact row counts and object inventories match." | tee -a "$OUT/RESULT.txt"
else
  echo "FAIL: differences detected; inspect rowcounts.diff and objects.diff." | tee -a "$OUT/RESULT.txt"
  exit 1
fi

echo "Comparison artifacts: $OUT"
