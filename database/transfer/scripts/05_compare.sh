#!/usr/bin/env bash
set -euo pipefail

SRC_URL="${METRA_SRC_DATABASE_URL:?}"
DST_URL="${METRA_DST_DATABASE_URL:?}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${METRA_TRANSFER_OUT:-$ROOT/artifacts/compare-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$OUT"

psql "$SRC_URL" -v ON_ERROR_STOP=1 -f "$ROOT/sql/compare_rowcounts.sql" -o "$OUT/source_rowcounts.txt"
psql "$DST_URL" -v ON_ERROR_STOP=1 -f "$ROOT/sql/compare_rowcounts.sql" -o "$OUT/target_rowcounts.txt"
psql "$SRC_URL" -v ON_ERROR_STOP=1 -f "$ROOT/sql/compare_objects.sql" -o "$OUT/source_objects.txt"
psql "$DST_URL" -v ON_ERROR_STOP=1 -f "$ROOT/sql/compare_objects.sql" -o "$OUT/target_objects.txt"

echo "Compare outputs in $OUT"
echo "Diff example: diff -u $OUT/source_rowcounts.txt $OUT/target_rowcounts.txt"
