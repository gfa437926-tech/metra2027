#!/usr/bin/env bash
# Install only extensions recorded in the verified experimental source inventory.
# Versions are not pinned in CREATE EXTENSION; exact versions are checked afterwards.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/project_url_guard.sh"
DST_REF="${METRA_DST_PROJECT_REF:?Set METRA_DST_PROJECT_REF}"
DST_URL="${METRA_DST_DATABASE_URL:?Set METRA_DST_DATABASE_URL}"
DUMP_DIR="${1:?Usage: 02_install_required_extensions.sh /path/to/export_stamp_dir}"

for forbidden_ref in tbdnklyxjvbrilvnwgmq nhovijnbtrocqahxxjou wdrcqceiagsmdxltqfwd vktcvkwqszehgmhqjrkb; do
  if [[ "$DST_REF" == "$forbidden_ref" ]]; then
    echo "Refusing: target must be a new, non-legacy Supabase project." >&2
    exit 3
  fi
done
metra_assert_supabase_project_url "$DST_REF" "$DST_URL" "target"
command -v psql >/dev/null 2>&1 || { echo "psql is required." >&2; exit 4; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required." >&2; exit 4; }
[[ -s "$DUMP_DIR/SHA256SUMS" ]] || { echo "Missing SHA256SUMS." >&2; exit 4; }
[[ -s "$DUMP_DIR/07_extensions.txt" ]] || { echo "Missing required extension inventory." >&2; exit 4; }

(
  cd "$DUMP_DIR"
  sha256sum --check --strict SHA256SUMS
)
metra_verify_transfer_manifest "$DUMP_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
SQL_FILE="$TMP_DIR/install_extensions.sql"
: > "$SQL_FILE"

while IFS='|' read -r extension_name source_version extension_schema; do
  [[ -z "$extension_name" ]] && continue
  if [[ ! "$extension_name" =~ ^[A-Za-z0-9_-]+$ || ! "$extension_schema" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Refusing extension inventory entry with an unsafe identifier." >&2
    exit 5
  fi
  [[ -n "$source_version" ]] || { echo "Refusing extension with missing source version: $extension_name" >&2; exit 5; }

  # PL/pgSQL is a PostgreSQL built-in in pg_catalog; it is already installed.
  if [[ "$extension_schema" == "pg_catalog" ]]; then
    continue
  fi

  printf 'CREATE SCHEMA IF NOT EXISTS "%s";\n' "$extension_schema" >> "$SQL_FILE"
  printf 'CREATE EXTENSION IF NOT EXISTS "%s" WITH SCHEMA "%s";\n' \
    "$extension_name" "$extension_schema" >> "$SQL_FILE"
done < "$DUMP_DIR/07_extensions.txt"

if [[ ! -s "$SQL_FILE" ]]; then
  echo "No non-built-in extensions required by the source." >&2
else
  echo "Installing missing source extensions into verified target $DST_REF."
  psql "$DST_URL" -X -1 -v ON_ERROR_STOP=1 -f "$SQL_FILE"
fi

psql "$DST_URL" -X -v ON_ERROR_STOP=1 -At \
  -f "$SCRIPT_DIR/../sql/compare_extensions.sql" > "$TMP_DIR/target_extensions.txt"
while IFS= read -r required_extension; do
  [[ -z "$required_extension" ]] && continue
  if ! grep -Fxq "$required_extension" "$TMP_DIR/target_extensions.txt"; then
    echo "Refusing: target extension/version/schema mismatch: $required_extension" >&2
    exit 6
  fi
done < "$DUMP_DIR/07_extensions.txt"

echo "Required source extensions are installed with matching versions and schemas."
