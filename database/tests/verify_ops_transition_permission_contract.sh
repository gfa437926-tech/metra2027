#!/usr/bin/env bash
set -euo pipefail

migration="supabase/migrations/20261107032000_harden_ops_rls_and_assignee_checks.sql"
api_fault="backend/Metra.Api/Features/Maintenance/EquipmentFaultEndpoints.cs"
api_support="backend/Metra.Api/Features/Support/SupportIncidentEndpoints.cs"

require_in() {
  local file="$1"
  local fragment="$2"
  if ! grep -Fq "$fragment" "$file"; then
    echo "Missing permission contract in $file: $fragment" >&2
    exit 1
  fi
}

# Keep the SQL security-definer RPC's independent permission check identical
# to the API's least-privilege transition map.
require_in "$api_fault" 'EquipmentFaultStatus.InProgress => "equipment_fault.update"'
require_in "$api_fault" 'EquipmentFaultStatus.Resolved or EquipmentFaultStatus.Closed => "equipment_fault.resolve"'
require_in "$api_support" 'SupportIncidentStatus.InProgress or SupportIncidentStatus.WaitingForInformation'
require_in "$api_support" '=> "support_incident.update"'
require_in "$api_support" 'SupportIncidentStatus.Resolved or SupportIncidentStatus.Closed => "support_incident.resolve"'

require_in "$migration" "when 'InProgress' then 'equipment_fault.update'"
require_in "$migration" "when 'Resolved' then 'equipment_fault.resolve'"
require_in "$migration" "when 'Closed' then 'equipment_fault.resolve'"
require_in "$migration" "when 'InProgress' then 'support_incident.update'"
require_in "$migration" "when 'WaitingForInformation' then 'support_incident.update'"
require_in "$migration" "when 'Resolved' then 'support_incident.resolve'"
require_in "$migration" "when 'Closed' then 'support_incident.resolve'"
require_in "$migration" "'equipment_fault.update') then"
require_in "$migration" "'support_incident.update') then"

if grep -Eq "equipment_fault\\.(progress|close)|support_incident\\.(progress|close)" "$migration"; then
  echo "Legacy transition permission aliases remain in SQL RPC." >&2
  exit 1
fi

echo "Support/maintenance transition permission contract verified."
