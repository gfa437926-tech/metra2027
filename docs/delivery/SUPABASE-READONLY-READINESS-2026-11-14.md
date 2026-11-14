# METRA 2027 — Supabase read-only readiness audit

- Audit date: 2026-11-14
- Project: `tbdnklyxjvbrilvnwgmq` (`metra2027-angular`)
- Region: `eu-west-2`
- Project status: `ACTIVE_HEALTHY`
- PostgreSQL: `17.11.0.016`
- Scope: read-only SQL and Supabase advisors only. No schema, data, Auth, policy, extension, or project settings were changed.

## 1. Exact row-count snapshot

The following counts were obtained with exact `COUNT(*)` queries on 2026-11-14:

| Table | Rows |
|---|---:|
| authority_access_audit_events | 0 |
| authority_memberships | 0 |
| countries | 1 |
| meteorological_authorities | 1 |
| metra_account_states | 0 |
| metra_equipment_fault_audit_events | 0 |
| metra_equipment_faults | 0 |
| metra_observation_audit_events | 0 |
| metra_observation_records | 58,059 |
| metra_observations | 0 |
| metra_role_catalogue | 8 |
| metra_role_permissions | 18 |
| metra_support_incident_audit_events | 0 |
| metra_support_incidents | 0 |
| metra_user_profiles | 0 |
| permission_grants | 0 |
| registration_audit_events | 0 |
| registration_requests | 0 |
| station_access_grants | 0 |
| station_assignments | 0 |
| station_audit_log | 0 |
| station_catalogue | 65 |
| station_coordinates | 50 |
| auth.users | 0 |

## 2. Transfer boundaries confirmed

### Auth

- `auth.users` contains **0** rows.
- There are **44** foreign keys referencing `auth.users(id)`; all 44 are validated and 0 are unvalidated.
- No Auth user identities, password hashes, sessions, refresh tokens, or JWT secrets are required in this transfer.
- The export manifest and import scripts enforce `auth_user_count=0`; do not bypass that guard.

### Observation history

- `metra_observation_records` contains **58,059** rows.
- Demo rows: **0**. Non-demo rows: **58,059**.
- Rows with no `station_id`: **1,251**.
- All observation rows (demo and non-demo) are excluded from this transfer package. This avoids copying historical operational records and avoids carrying forward the unresolved station references.
- Any later demo observations must be synthetic and supplied through a separately reviewed seed fixture.

### Station catalogue and coordinates

- `station_catalogue`: **65** rows, comprising 3 demo and 62 non-demo.
- Approval status: **65 pending**, 0 approved, 0 rejected.
- Current coordinates: **50** rows for 50 distinct stations.
- Stations without a current coordinate: **15**.
- Orphan coordinate rows: **0**.
- Duplicate current station-coordinate links: **0**.
- Export must preserve all station statuses and source provenance exactly. Do not approve stations or invent missing coordinates during transfer.

## 3. RLS and access review

- All 23 public application tables have RLS enabled.
- Four public equipment-fault/support-incident tables have no RLS policies. They also have no `anon` or `authenticated` table grants in the inspected grant inventory; only `postgres` and `service_role` have table privileges. This is currently default-deny for browser roles.
- `metra_migration.legacy_users_staging` has RLS enabled and no policies. It is outside the transfer export scope because the transfer pack exports only `public/private`.
- Do not add client policies to the four server-only tables without an explicit access-model review.

## 4. Supabase advisor findings

### Security

- The source has broad default privileges for objects created by `postgres` in `public`: `anon` and `authenticated` receive ALL table and sequence privileges and function EXECUTE by default, alongside `service_role`. This is recorded in the source ACL inventory but will **not** be copied to the new target.
- The target transfer scripts now apply a stricter default: only `service_role` receives implicit privileges on future public tables, sequences, and functions. `PUBLIC`, `anon`, and `authenticated` receive none; existing object access is granted explicitly and tested.
- Two warnings report mutable function search paths:
  - `public.reject_metra_equipment_fault_audit_mutation`
  - `public.reject_metra_support_incident_audit_mutation`
- Read-only definition review confirms both are **SECURITY INVOKER** trigger functions whose bodies only raise an exception; neither reads tables or performs privileged operations. The target transfer pack now pins these functions (and the two already-safe audit triggers) to `search_path=pg_catalog` and asserts the setting. The experimental source remains unchanged.

### Performance

- 10 unindexed foreign-key warnings affect the equipment-fault and support-incident tables:
  - equipment fault audit: actor, fault, station
  - equipment faults: assigned user, reporter user
  - support incident audit: actor, incident, station
  - support incidents: assigned user, reporter user
- Add targeted indexes in a reviewed migration after confirming expected query patterns. **Not applied**.
- 46 unused-index notices were also returned. Most application tables are empty or have very little workload; do not drop indexes based on this snapshot alone.

### Health

- No health advisor findings were returned.

## 5. Installed extension inventory

The installed extensions reported by Supabase were:

- `pg_stat_statements` 1.11
- `plpgsql` 1.0
- `pg_trgm` 1.6
- `btree_gist` 1.7
- `supabase_vault` 0.3.1
- `uuid-ossp` 1.1
- `pgcrypto` 1.3

The transfer package records installed extension names, versions, and schemas and refuses to continue if the target is missing a required source extension.

## 6. Actions deliberately not taken

- No data was inserted, updated, or deleted.
- No Auth users, passwords, sessions, or identities were exported.
- No RLS policies or grants were changed.
- No indexes or functions were altered.
- No migrations were applied.
- No old METRA database was accessed.
- No target Supabase project was created or selected.

## 7. Remaining gates

1. Keep the experimental source unchanged while the transfer scripts continue to pass isolated CI.
2. Review the two function search-path warnings and 10 missing-FK-index findings; prepare a migration proposal, but do not apply it before approval.
3. Confirm the 15 missing station coordinates with authoritative source material; do not fabricate values.
4. Create/name the new Supabase target project and verify its identity and region.
5. Run the encrypted export in a secure runtime, verify SHA-256, then restore into an empty target.
6. Compare exact row counts, non-Auth-FK content fingerprints, Auth FK cardinality, sequence state, object inventory, extensions, station provenance, and ACL inventory.
7. Perform application smoke tests and a full restore drill before cutover.

**This report is a read-only readiness snapshot, not a claim that a live export, import, restore, or cutover has occurred.**
