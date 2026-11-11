# METRA 2027 — Baseline schema pack (generic PostgreSQL)

**Purpose:** Rebuild core relational structure from an **empty** PostgreSQL database for isolated verification.

**Not for hosted Supabase apply without explicit approval.**  
**Does not replace Supabase Auth.**  
**Does not contain operational station catalogues from METRA OLD.**

## Observation tables — source of truth

| Table | Authoritative definition | In Baseline? |
|-------|--------------------------|--------------|
| `metra_observations` | `supabase/migrations/20261103164003_create_operational_observation_submission.sql` | **No** (avoid duplicate CREATE) |
| `metra_observation_audit_events` | same file | **No** |

After baseline + required stubs, apply `supabase/migrations/` when testing observation RPCs in isolation (requires Supabase-like roles or adapter).

## ArchiveRead policy (design constraint on data)

- Grant must bind **user + station** (`permission_grants.station_id`).
- `station_id IS NULL` must **not** authorize `observation.archive.read`.
- Role or authority membership alone is insufficient.
- Production RPC change is **out of scope** for this pack (see migration proposal 031).

## Apply order (empty database)

```bash
psql -v ON_ERROR_STOP=1 -f database/baseline/001_extensions_and_schemas.sql
psql -v ON_ERROR_STOP=1 -f database/baseline/002_identity_stub.sql
psql -v ON_ERROR_STOP=1 -f database/baseline/003_org_and_stations.sql
psql -v ON_ERROR_STOP=1 -f database/baseline/004_roles_and_permission_catalogue.sql
psql -v ON_ERROR_STOP=1 -f database/baseline/005_memberships_assignments_grants.sql
psql -v ON_ERROR_STOP=1 -f database/baseline/006_registration_and_station_audit.sql
psql -v ON_ERROR_STOP=1 -f database/baseline/007_audit_append_only.sql
psql -v ON_ERROR_STOP=1 -f database/baseline/008_indexes.sql
# optional isolated seeds only:
# psql -f database/baseline/seeds/001_isolated_smoke_roles.sql
```

## Files

| File | Contents |
|------|----------|
| 001 | extensions, schemas |
| 002 | `auth.users` **stub** (isolated only) |
| 003 | countries, authorities, station_catalogue |
| 004 | role catalogue, role_permissions, permission_codes |
| 005 | account_states, memberships, assignments, permission_grants |
| 006 | registration_requests, profiles stub, station_audit_log |
| 007 | append-only audit tables + triggers |
| 008 | indexes |
| seeds/ | optional non-operational smoke data |

## Supabase vs generic PostgreSQL

| Concern | Baseline (generic) | Hosted Supabase |
|---------|--------------------|-----------------|
| `auth.users` | Stub table | Real Auth schema |
| Roles anon/authenticated/service_role | Not created here | Platform roles |
| RLS | Not enabled here | Required for client paths |
| Observations | Deferred to supabase migrations | Applied in project |
