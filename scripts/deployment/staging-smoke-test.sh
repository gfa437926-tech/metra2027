#!/usr/bin/env bash
set -euo pipefail

API_BASE="\${METRA_STAGING_API_BASE_URL:-}"
if [[ -z "$API_BASE" ]]; then
  echo "METRA_STAGING_API_BASE_URL is required (HTTPS URL ending in /api/v1)." >&2
  exit 2
fi
if [[ "$API_BASE" != https://* || "$API_BASE" == *\?* || "$API_BASE" == *\#* || "$API_BASE" == *"@"* ]]; then
  echo "Refusing unsafe staging API URL; use an HTTPS origin without credentials, query, or fragment." >&2
  exit 2
fi
API_BASE="\${API_BASE%/}"
if [[ "$API_BASE" != */api/v1 ]]; then
  echo "METRA_STAGING_API_BASE_URL must end in /api/v1." >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

curl --fail --silent --show-error --connect-timeout 8 --max-time 20 \
  "$API_BASE/health" -o "$tmp_dir/health.json"
if ! grep -Eq '"status"[[:space:]]*:[[:space:]]*"healthy"' "$tmp_dir/health.json"; then
  echo "Health endpoint did not return status=healthy." >&2
  exit 1
fi
echo "staging health: PASS"

ready_status="$(curl --silent --show-error --connect-timeout 8 --max-time 30 \
  -o "$tmp_dir/ready.json" -w '%{http_code}' "$API_BASE/ready")"
if [[ "$ready_status" != "200" ]] || ! grep -Eq '"status"[[:space:]]*:[[:space:]]*"ready"' "$tmp_dir/ready.json"; then
  echo "Staging readiness failed (HTTP \${ready_status}); no response body is printed to avoid leaking configuration details." >&2
  exit 1
fi
echo "staging readiness: PASS"
echo "No write or migration requests were sent."
