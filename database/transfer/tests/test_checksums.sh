#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/project_url_guard.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

required_files=(
  01_schema_application.sql.gpg
  02_data_application.sql.gpg
  03_inventory_tables.txt
  03_inventory_functions.txt
  04_auth_user_fk_inventory.txt
  05_observation_provenance.txt
  06_runtime_role_inventory.txt
  07_extensions.txt
  08_station_catalogue_provenance.txt
  MANIFEST.txt
)
for file in "${required_files[@]}"; do
  printf 'fixture:%s\n' "$file" > "$TMP_DIR/$file"
done
(
  cd "$TMP_DIR"
  sha256sum "${required_files[@]}" > SHA256SUMS
)
metra_verify_transfer_checksums "$TMP_DIR"

# Modified artifact must fail checksum validation.
printf 'tampered\n' >> "$TMP_DIR/07_extensions.txt"
if metra_verify_transfer_checksums "$TMP_DIR"; then
  echo "FAIL: tampered artifact was accepted." >&2
  exit 1
fi

# Restore and regenerate a valid checksum list.
printf 'fixture:07_extensions.txt\n' > "$TMP_DIR/07_extensions.txt"
(
  cd "$TMP_DIR"
  sha256sum "${required_files[@]}" > SHA256SUMS
)

# Duplicate artifact entries are rejected.
first_line="$(head -n 1 "$TMP_DIR/SHA256SUMS")"
printf '%s\n' "$first_line" >> "$TMP_DIR/SHA256SUMS"
if metra_verify_transfer_checksums "$TMP_DIR"; then
  echo "FAIL: duplicate checksum entry was accepted." >&2
  exit 1
fi
(
  cd "$TMP_DIR"
  sha256sum "${required_files[@]}" > SHA256SUMS
)

# Path traversal and unexpected files are rejected before sha256sum reads them.
printf '%064d  ../../outside-file\n' 0 >> "$TMP_DIR/SHA256SUMS"
if metra_verify_transfer_checksums "$TMP_DIR"; then
  echo "FAIL: unsafe checksum path was accepted." >&2
  exit 1
fi

# A manifest that omits one required artifact is rejected.
(
  cd "$TMP_DIR"
  sha256sum "${required_files[@]:1}" > SHA256SUMS
)
if metra_verify_transfer_checksums "$TMP_DIR"; then
  echo "FAIL: incomplete checksum manifest was accepted." >&2
  exit 1
fi

echo "PASS: checksum integrity, exact artifact set, and path traversal guards."
