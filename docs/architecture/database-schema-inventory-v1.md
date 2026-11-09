# METRA database schema inventory (from repository migrations only)

**Status:** design inventory — **not** an applied production schema certificate.  
**Source tip:** work branch migrations under `supabase/migrations` and `database/migrations` + `database/bootstrap`.  
**Rule:** no APPLY without explicit owner approval.

## Core catalogue and identity (referenced / bootstrap)

These objects are referenced by operational migrations and/or created in test bootstrap:

| Object | Role |
|---|---|
| `station_catalogue` | Canonical stations (new catalogue only) |
| `meteorological_authorities` | Owner authorities for stations |
| `metra_station_permission_grants` | Per-user station permissions |
| `auth.users` | Supabase Auth subjects (platform) |

## Operational tables defined in supabase/migrations

| Table | Purpose |
|---|---|
| `metra_observations` | Submitted observations (station-scoped) |
| `metra_observation_audit_events` | Immutable observation audit |
| `metra_equipment_faults` | Equipment fault tickets |
| `metra_equipment_fault_audit_events` | Fault audit |
| `metra_support_incidents` | Support incidents |
| `metra_support_incident_audit_events` | Support audit |
| `authority_access_audit_events` | Authority membership/grant audit |

## Representative RPCs (server-side)

Observation: `metra_submit_observation`, `metra_decide_observation`, `metra_resubmit_observation`  
Faults: `metra_submit_equipment_fault`, `metra_transition_equipment_fault`  
Support: `metra_submit_support_incident`, `metra_transition_support_incident`  
Station/authz: `metra_user_has_station_permission`, assignment/registration/authority decision RPCs  

## RLS posture (from files)

- Several migrations **enable RLS** and **revoke** direct `anon` / `authenticated` access on operational tables.
- Many execute grants target **`service_role`** (API uses service role after JWT + station checks).
- Npgsql ops path adds **session context** helpers for station/user binding (`20261108020000_npgsql_ops_session_context_rls.sql`).

## Explicit non-goals of this inventory

- Does not prove migrations were applied on project `tbdnklyxjvbrilvnwgmq`.
- Does not document `legacy_users_staging` (not present in repository migrations).
- Does not authorize schema changes.
