#!/usr/bin/env bash
# Contract checklist for observation lifecycle against a live API.
# Requires METRA_API_BASE_URL and METRA_ACCESS_TOKEN and METRA_STATION_ID.
# Does not print secrets. Fails closed if required env is missing.
set -euo pipefail

BASE="${METRA_API_BASE_URL:-}"
TOKEN="${METRA_ACCESS_TOKEN:-}"
STATION="${METRA_STATION_ID:-}"

if [ -z "$BASE" ] || [ -z "$TOKEN" ] || [ -z "$STATION" ]; then
  echo "SKIP: METRA_API_BASE_URL, METRA_ACCESS_TOKEN, METRA_STATION_ID required for live observation lifecycle"
  exit 0
fi

auth=(-H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json")

echo "== submit draft/submit observation"
SUBMIT=$(curl -sS -X POST "${BASE}/api/v1/stations/${STATION}/observations" \
  "${auth[@]}" \
  -d '{"observationType":"hourly","observedAt":"'"$(date -u +%Y-%m-%dT%H:00:00Z)"'","payload":{"dry_bulb_c":22.5},"submit":true}')
echo "$SUBMIT" | grep -q '"id"' || { echo "submit failed"; exit 1; }
OID=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"$SUBMIT")

echo "== list queue"
curl -sS -f "${BASE}/api/v1/stations/${STATION}/observations?status=Submitted" "${auth[@]}" >/dev/null

echo "== decide return"
curl -sS -f -X POST "${BASE}/api/v1/stations/${STATION}/observations/${OID}/decision" \
  "${auth[@]}" \
  -d '{"decision":"return","reviewNote":"correct wet bulb"}' >/dev/null

echo "== resubmit"
curl -sS -f -X POST "${BASE}/api/v1/stations/${STATION}/observations/${OID}/resubmit" \
  "${auth[@]}" \
  -d '{"payload":{"dry_bulb_c":22.5,"wet_bulb_c":18.0},"submit":true}' >/dev/null

echo "== decide approve"
curl -sS -f -X POST "${BASE}/api/v1/stations/${STATION}/observations/${OID}/decision" \
  "${auth[@]}" \
  -d '{"decision":"approve","reviewNote":"ok"}' >/dev/null

echo "observation_lifecycle_api_contract: PASS"
