#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib/project_url_guard.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/MANIFEST.txt" <<'EOF'
source_project_ref=tbdnklyxjvbrilvnwgmq
auth_users_exported=false
observation_records_data_exported=false
non_demo_observation_records_excluded=true
runtime_role_inventory_exported=true
required_extensions_inventory_exported=true
api_keys_and_jwt_secrets_exported=false
EOF
metra_verify_transfer_manifest "$TMP_DIR"

sed 's/observation_records_data_exported=false/observation_records_data_exported=true/' "$TMP_DIR/MANIFEST.txt" > "$TMP_DIR/bad-manifest.txt"
mv "$TMP_DIR/bad-manifest.txt" "$TMP_DIR/MANIFEST.txt"
if metra_verify_transfer_manifest "$TMP_DIR"; then
  echo "FAIL: unsafe manifest was accepted." >&2
  exit 1
fi
echo "PASS: transfer manifest provenance and exclusion guard."
