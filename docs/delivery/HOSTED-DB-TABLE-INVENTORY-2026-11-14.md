# Hosted experimental DB table inventory

**Project ref (only):** `tbdnklyxjvbrilvnwgmq`  
**Source:** owner-provided read-only `information_schema` listing (2026-11-14)  
**Method:** SQL Editor (no service_role in chat; no legacy DB)

## Public tables present (23)

| table_name |
| --- |
| authority_access_audit_events |
| authority_memberships |
| countries |
| meteorological_authorities |
| metra_account_states |
| metra_equipment_fault_audit_events |
| metra_equipment_faults |
| metra_observation_audit_events |
| metra_observation_records |
| metra_observations |
| metra_role_catalogue |
| metra_role_permissions |
| metra_support_incident_audit_events |
| metra_support_incidents |
| metra_user_profiles |
| permission_grants |
| registration_audit_events |
| registration_requests |
| station_access_grants |
| station_assignments |
| station_audit_log |
| station_catalogue |
| station_coordinates |

## Alignment with Path N / baseline expectations

**Present and expected for core product paths**

- Org / stations: `countries`, `meteorological_authorities`, `station_catalogue`, `station_coordinates`
- Identity / access: `metra_user_profiles`, `metra_account_states`, `authority_memberships`, `station_assignments`, `permission_grants`, `station_access_grants`
- Roles: `metra_role_catalogue`, `metra_role_permissions`
- Registration: `registration_requests`, `registration_audit_events`
- Station ops audit: `station_audit_log`, `authority_access_audit_events`
- Observations (ops tables exist): `metra_observations`, `metra_observation_records`, `metra_observation_audit_events`
- Support / equipment: `metra_support_incidents`, `metra_support_incident_audit_events`, `metra_equipment_faults`, `metra_equipment_fault_audit_events`

**Possibly missing vs baseline / proposals (to verify next)**

- `metra_permission_codes` (catalogue of permission codes; may be folded into role permissions only)
- `permission_grant_audit` (append-only grant history table from baseline 007)
- Dedicated **observation archive read-model** tables (archive remains fail-closed in API until approved service exists)
- Confirmation of R4-related RPC / functions: `metra_user_has_station_permission` and archive bind proposals 030/031 **not proven deployed** from table list alone

## Product implications (honest)

| Capability | Hosted table evidence | App/API posture |
| --- | --- | --- |
| Stations / catalogue | Yes | liveApi |
| Users / grants / assignments | Yes | liveApi reads |
| Registration | Yes | liveApi reads |
| Station audit log | Yes | liveApi |
| Observation storage tables | Yes | submit/decision remain **gated** until scientific contract + atomic RPC proven |
| Archive product path | No dedicated live archive service proven | **503 / fail-closed** |
| AI / Climatol / Forecast | N/A tables | mock |

## Next read-only checks (SQL Editor)

```sql
-- row counts
SELECT relname AS table_name, n_live_tup AS est_rows
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY relname;

-- permission-related functions
SELECT n.nspname, p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public')
  AND p.proname ILIKE '%permission%'
ORDER BY 1, 2;

-- archive-related objects
SELECT n.nspname, p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%archive%'
ORDER BY 1, 2;
```

## Constraints

- No writes performed on hosted DB from this inventory.
- Legacy METRA DB remains forbidden.
- Secrets must not be pasted into chat; rotate any previously exposed API keys.
