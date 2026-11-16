# METRA 2027 — Baseline Schema Gap & Proposal (Stage D deliverable)

**Status:** Proposal only — **not implemented**. Requires explicit human approval before any CREATE TABLE pack is added or applied.  
**Hosted Supabase:** must not receive this without a separate approval.  
**Legacy DB:** out of scope.

## 1. Problem statement

`database/migrations/` starts at `003_*` and assumes pre-existing relations and Supabase roles. Applying the folder to an empty generic PostgreSQL database fails (Stage C evidence): missing `metra_account_states`, `metra_role_permissions`, `station_catalogue`, role `anon`, etc.

Existing CI scripts `database/tests/verify_*.sh` only **grep** SQL source contracts; they do not create a blank DB and replay migrations.

## 2. Tables / objects referenced by migrations but not created in 003–029

Inferred from migration JOIN/INSERT targets and supabase operational files (non-exhaustive; must be confirmed against live hosted schema before any apply):

| Object | Referenced by | Created in repo migrations? |
|--------|---------------|------------------------------|
| `auth.users` | assignments, observations, audits | No (Supabase Auth) |
| `public.countries` | station permission RPC | No in 003–029 |
| `public.meteorological_authorities` | station permission RPC | No |
| `public.station_catalogue` | nearly all station RPCs | No |
| `public.metra_account_states` | station permission RPC | No |
| `public.authority_memberships` | station permission RPC; 020+ | Partially evolved in 020+ |
| `public.station_assignments` | station permission RPC; 012+ | Partially evolved |
| `public.metra_role_catalogue` | seeds + RPCs | Seed only (`seeds/001_role_catalogue.sql`) |
| `public.metra_role_permissions` | 003–011 inserts | No CREATE in tree |
| `public.permission_grants` | 003+ | Evolved in 020–021 |
| `public.metra_observations` | supabase migrations | Yes (supabase/) |
| `public.metra_observation_audit_events` | supabase migrations | Yes (supabase/) |
| roles `anon`, `authenticated`, `service_role`, `metra_api_runtime` | REVOKE/GRANT in many files | Supabase-specific |

## 3. Split: generic PostgreSQL vs Supabase

| Concern | Generic PostgreSQL | Supabase project |
|---------|--------------------|------------------|
| Auth users | Must stub or omit | `auth.users` managed by Auth |
| Roles anon/authenticated/service_role | Do not invent blindly | Provided by platform |
| RLS | Optional for local | Required for client paths |
| RPC SECURITY DEFINER + service_role EXECUTE | Emulate carefully | Production pattern |

**Recommendation:** maintain two tracks:

1. **`database/isolated/`** — minimal bootstrap for security unit tests (already used for archive isolation).  
2. **Future `database/baseline/` (proposed)** — ordered CREATE TABLE + constraints + indexes **without** assuming Supabase roles; a thin `database/baseline/supabase_roles_adapter.sql` applied only in Supabase environments.

Never copy Supabase roles into generic PG as if they were portable without adapters.

## 4. Proposed creation order (for future pack — not written yet)

1. Extensions / schemas (`auth` stub only for isolated tests)  
2. `countries` → `meteorological_authorities` → `station_catalogue`  
3. `metra_role_catalogue` → `metra_role_permissions`  
4. `metra_account_states`  
5. `authority_memberships` → `station_assignments`  
6. `permission_grants` + append-only grant audit  
7. Then existing incremental migrations 003+  
8. Then `supabase/migrations` operational observation objects (or a merged path)

## 5. Constraints & indexes (minimum for security)

- PK/FK on all assignment and grant relations  
- Unique active grant per (user_id, station_id, permission_code) where business rules require  
- Indexes on `(station_id, user_id)`, `(permission_code, station_id)`, audit `(occurred_at)`  
- Triggers rejecting UPDATE/DELETE on audit tables  

## 6. Approval gate

No baseline pack will be committed as executable production DDL until you approve:

- scope of tables  
- whether auth.users is stubbed or required only on Supabase  
- naming of adapter files  

Stage D stops at this document.
