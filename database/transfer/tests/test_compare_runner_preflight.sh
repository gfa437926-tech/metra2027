#!/usr/bin/env bash
# Prove 05_compare.sh rejects unsafe project identities and URLs before psql.
# A fake psql executable records calls; no network or hosted database is used.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
RUNNER="$ROOT/database/transfer/scripts/05_compare.sh"
WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

mkdir -p "$WORK_DIR/bin"
cat > "$WORK_DIR/bin/psql" <<'PSQL'
#!/usr/bin/env bash
printf 'called\n' >> "$METRA_PSQL_MARKER"
exit 97
PSQL
chmod 700 "$WORK_DIR/bin/psql"

export PATH="$WORK_DIR/bin:$PATH"
export METRA_PSQL_MARKER="$WORK_DIR/psql-calls"
export METRA_TRANSFER_OUT="$WORK_DIR/compare-output"
SOURCE_REF="tbdnklyxjvbrilvnwgmq"
TARGET_REF="newmetratarget12345678"
SOURCE_URL="postgresql://postgres:ci-secret@db.tbdnklyxjvbrilvnwgmq.supabase.co:5432/postgres"
TARGET_URL="postgresql://postgres:ci-secret@db.newmetratarget12345678.supabase.co:5432/postgres"

expect_preflight_rejection() {
  local label="$1"
  shift
  rm -f "$METRA_PSQL_MARKER"
  if env PATH="$PATH" METRA_PSQL_MARKER="$METRA_PSQL_MARKER" \
    METRA_TRANSFER_OUT="$WORK_DIR/$label-output" "$@" bash "$RUNNER" \
    >"$WORK_DIR/$label.stdout" 2>"$WORK_DIR/$label.stderr"; then
    echo "FAIL: $label unexpectedly passed preflight." >&2
    exit 1
  fi
  if [[ -e "$METRA_PSQL_MARKER" ]]; then
    echo "FAIL: $label reached psql before rejecting unsafe configuration." >&2
    exit 1
  fi
}

expect_preflight_rejection "wrong-source-ref" \
  METRA_SRC_PROJECT_REF="wrongproject12345678" \
  METRA_DST_PROJECT_REF="$TARGET_REF" \
  METRA_SRC_DATABASE_URL="$SOURCE_URL" METRA_DST_DATABASE_URL="$TARGET_URL"

expect_preflight_rejection "same-source-target" \
  METRA_SRC_PROJECT_REF="$SOURCE_REF" METRA_DST_PROJECT_REF="$SOURCE_REF" \
  METRA_SRC_DATABASE_URL="$SOURCE_URL" METRA_DST_DATABASE_URL="$SOURCE_URL"

for legacy_ref in nhovijnbtrocqahxxjou wdrcqceiagsmdxltqfwd vktcvkwqszehgmhqjrkb; do
  expect_preflight_rejection "legacy-target-$legacy_ref" \
    METRA_SRC_PROJECT_REF="$SOURCE_REF" METRA_DST_PROJECT_REF="$legacy_ref" \
    METRA_SRC_DATABASE_URL="$SOURCE_URL" \
    METRA_DST_DATABASE_URL="postgresql://postgres:ci-secret@db.$legacy_ref.supabase.co:5432/postgres"
done

expect_preflight_rejection "wrong-source-url" \
  METRA_SRC_PROJECT_REF="$SOURCE_REF" METRA_DST_PROJECT_REF="$TARGET_REF" \
  METRA_SRC_DATABASE_URL="postgresql://postgres:ci-secret@db.wrongproject.supabase.co:5432/postgres" \
  METRA_DST_DATABASE_URL="$TARGET_URL"

expect_preflight_rejection "wrong-target-url" \
  METRA_SRC_PROJECT_REF="$SOURCE_REF" METRA_DST_PROJECT_REF="$TARGET_REF" \
  METRA_SRC_DATABASE_URL="$SOURCE_URL" \
  METRA_DST_DATABASE_URL="postgresql://postgres:ci-secret@db.wrongproject.supabase.co:5432/postgres"

# Valid identities must pass every preflight guard and reach the fake psql.
rm -f "$METRA_PSQL_MARKER"
set +e
env PATH="$PATH" METRA_PSQL_MARKER="$METRA_PSQL_MARKER" \
  METRA_TRANSFER_OUT="$WORK_DIR/valid-output" \
  METRA_SRC_PROJECT_REF="$SOURCE_REF" METRA_DST_PROJECT_REF="$TARGET_REF" \
  METRA_SRC_DATABASE_URL="$SOURCE_URL" METRA_DST_DATABASE_URL="$TARGET_URL" \
  bash "$RUNNER" >"$WORK_DIR/valid.stdout" 2>"$WORK_DIR/valid.stderr"
status=$?
set -e
if [[ "$status" -ne 97 || ! -s "$METRA_PSQL_MARKER" ]]; then
  echo "FAIL: valid project identities did not pass preflight to the fake psql (status=$status)." >&2
  cat "$WORK_DIR/valid.stderr" >&2
  exit 1
fi

echo "PASS: compare runner rejects wrong, identical, and legacy project identities before any database client call."
