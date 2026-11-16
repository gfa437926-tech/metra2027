# METRA 2027 — R4 Review + Baseline Schema Design (no execution)

**Branch:** `work/backend-db-integration-phase`  
**Base commit reviewed:** `9541b847019d7b0b6bb50f36b7ab8c8dcc524727`  
**This document:** review and design only. **No production RPC change. No DDL apply. No hosted writes.**

---

## Part I — R4: `permission_grants` station binding

### 1. Current production SQL (003)

File: `database/migrations/003_station_permission_rpc.sql`  
Function: `public.metra_user_has_station_permission(p_user_id, p_station_id, p_permission_code)`

Grant join (lines 41–44 approximately):

```sql
JOIN public.permission_grants AS permission
  ON permission.user_id = account.user_id
 AND permission.permission_code = p_permission_code
```

Station isolation in 003 comes from **assignment**:

```sql
JOIN public.station_assignments AS assignment
  ON assignment.user_id = account.user_id
 AND assignment.station_id = station.id
 ...
```

There is **no** `permission.station_id = p_station_id` (or `= station.id`).

### 2. Later replacement (020)

File: `database/migrations/020_authority_membership_and_permission_grant_lifecycle.sql`  
Lines 41–65 redefine the same function. Grant join becomes:

```sql
JOIN public.permission_grants g
  ON g.user_id = ac.user_id
 AND g.authority_id = s.owner_authority_id
 AND g.permission_code = p_permission_code
```

Still **no station_id on the grant**. Scope is **authority-level grant + station assignment**.

### 3. Isolated reference (approved ArchiveRead behavior)

File: `database/isolated/00_bootstrap_minimal_schema.sql` (approx. lines 130–138):

```sql
JOIN public.permission_grants AS permission
  ON permission.user_id = account.user_id
 AND permission.permission_code = p_permission_code
 AND permission.station_id = station.id
 AND permission.revoked_at IS NULL
 ...
```

### 4. Bypass / over-grant scenarios (for ArchiveRead policy)

| Scenario | 003 behavior | 020 behavior | Approved ArchiveRead policy |
|----------|--------------|--------------|------------------------------|
| User assigned to A and B; grant archive without station_id (or authority-wide grant) | May allow A and B if role allow-list matches | May allow A and B under same authority | **Must allow only stations with explicit station-bound grant** |
| Grant on A only; request B (same authority) | Depends on assignment to B + any matching grant row | Authority-bound grant + assignment B → **may allow B** | **Must deny B** |
| Role review only, no archive grant | Deny (no grant / role perm) | Deny | Deny |
| Revoked grant | Deny if revoked_at set | Deny | Deny |
| Expired assignment | Deny | Deny | Deny |

**Root issue for ArchiveRead:** treating grants as user+permission or user+authority+permission is weaker than **user+permission+station**.

### 5. Proposed predicate (design only — not applied)

Strict form for `observation.archive.read`:

```sql
AND (
  p_permission_code <> 'observation.archive.read'
  OR permission.station_id = p_station_id
)
```

Or always require station_id when column is present for station-scoped codes.

Optional compatibility for non-archive grants that historically omit station_id:

```sql
AND (
  permission.station_id IS NULL
  AND p_permission_code <> 'observation.archive.read'
  OR permission.station_id = p_station_id
)
```

**Recommended for ArchiveRead:** strict equality only; reject NULL station_id grants for that code.

### 6. Impact on other permissions

| Permission class | Likely impact of strict station bind on grant |
|------------------|-----------------------------------------------|
| `observation.create/submit/review/...` | Low if grants were authority-scoped and assignment already limits station; may require backfill of station_id on grants if product moves to per-station grants |
| `users.station.*` | Usually station-scoped already via assignment |
| `authority.access.*` | Uses `metra_user_has_authority_permission` — separate path; do not force station_id |
| `stations.catalogue.review` | Often authority/network scoped — evaluate separately |

**Do not** blindly add `station_id = p_station_id` to all permission codes without a data audit of existing `permission_grants` rows.

### 7. Required allow/deny tests (before any apply)

1. Archive grant station A → allow A  
2. Same user, grant A only → deny B (same authority)  
3. Authority-level grant only (no station_id) + assignments A,B → **deny** archive on A and B under strict policy  
4. Role allow-list without grant → deny  
5. Revoked grant → deny  
6. Expired assignment → deny  
7. Unauthenticated API → 401  
8. Regression: non-archive station permission still works for intended grant shape  

### 8. Rollback / compatibility plan

1. Ship migration as `CREATE OR REPLACE FUNCTION` only after data audit.  
2. Keep previous function body in migration comment or follow-up file for rollback replace.  
3. Backfill: for each approved archive grant missing station_id, either attach station_id or revoke and re-grant explicitly.  
4. Feature flag / keep API archive 503 until RPC + data + tests green.  
5. **Not applied in this phase.**

---

## Part II — Baseline Schema design (not created)

### A. Tables to create in a future Baseline pack

**Identity / roles (generic PG + isolated stub)**  
1. `auth.users` — **stub only in isolated/tests**; real Supabase uses Auth schema  
2. `metra_account_states`  
3. `metra_user_profiles` (if referenced)  
4. `metra_role_catalogue`  
5. `metra_role_permissions`  
6. `metra_permission_codes` (if used)

**Org / stations**  
7. `countries`  
8. `meteorological_authorities`  
9. `station_catalogue`  
10. `authority_memberships`  
11. `station_assignments`  
12. `permission_grants` (include nullable `station_id` + `authority_id`)  

**Audit (append-only)**  
13. `permission_grant_audit` or unify with `authority_access_audit_events`  
14. `station_audit_log` / read-model sources  
15. `registration_requests`, `registration_audit_events`  
16. `metra_observation_audit_events`  

**Observations (from supabase migrations — can be baseline or phase-2)**  
17. `metra_observations`  

### B. Created later by incremental migrations (keep as 003+)

- RPCs, review queues, hardening, authority lifecycle 015–029  
- Do not duplicate CREATE if baseline already has tables  

### C. Proposed future only (not baseline now)

- Forecast products, AI job tables, Climatol job tables, notification outbox, full electronic-record warehouse, report aggregates  

### D. Supabase-specific

- Roles: `anon`, `authenticated`, `service_role`, optional `metra_api_runtime`  
- RLS policies force on operational tables  
- `auth.users` real  

**Adapter strategy:**  
- `database/baseline/01_core_tables.sql` — no Supabase roles  
- `database/baseline/02_supabase_roles_and_grants.sql` — only on Supabase  
- `database/isolated/` — continues to use minimal stub `auth.users`  

### E. Creation order

1. schemas/extensions  
2. `auth.users` stub (isolated) / skip on Supabase  
3. countries → authorities → stations  
4. roles → role_permissions → permission_codes  
5. account_states → memberships → assignments → permission_grants  
6. audit tables + immutability triggers  
7. observations + observation audit  
8. run incremental 003+  
9. supabase operational deltas if not folded into baseline  

### F. Empty-DB replay target

`psql empty_db < baseline/*.sql && for f in migrations/003..029; do psql -f $f; done`  
Must not require hosted project.

---

## Part III — CI

Added job `isolated-archive-authz` on `backend-ci.yml`:

- service `postgres:16`  
- runs `database/isolated/00`, `01`, `02` with `ON_ERROR_STOP`  
- path filters include `database/isolated/**`  

This is **live SQL**, not grep.

---

## Part IV — Local .NET results (this environment)

| Step | Result |
|------|--------|
| `dotnet build backend/Metra.Api/Metra.Api.csproj -c Release` | **succeeded** (0 warnings, 0 errors) |
| Fix syntax in `ObservationAuthorizationPolicyTests.cs` (archive tests were outside class) | fixed in working tree |
| `dotnet test` full suite | **did not complete** in sandbox (timeout/hang on test project host); must rely on GitHub Actions `dotnet test` step |

---

## Decisions still requiring your approval

1. Apply strict `permission.station_id = p_station_id` for `observation.archive.read` only vs all station-scoped codes.  
2. Data backfill strategy for existing grants.  
3. Authorize writing the Baseline pack files (still not written as executable pack beyond isolated/).  
4. Enable hosted archive read-model (Endpoint stays 503 until then).

**Stop here — no RPC apply, no baseline DDL execution, no hosted changes.**
