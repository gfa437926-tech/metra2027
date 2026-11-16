# METRA 2027 — Stage C2: Baseline ↔ Migrations unification (inventory, design, evidence)

**Branch:** `work/backend-db-integration-phase`  
**Parent commit:** `9a0cfea423a4934a0bc28a49b613f12838afb53d`  
**Constraint:** inventory + design + isolated tests only. **No production migration rewrite. No hosted apply.**

---

## 1. Full migration inventory (summary)

### `database/baseline/` (empty-DB foundation)

| File | Creates |
|------|---------|
| 001 | extensions, schemas |
| 002 | `auth.users` stub (isolated only) |
| 003 | countries, meteorological_authorities, station_catalogue |
| 004 | metra_role_catalogue, metra_permission_codes, metra_role_permissions |
| 005 | metra_account_states, authority_memberships, station_assignments, permission_grants (**includes authority_id + station_id**, CHECK archive requires station_id) |
| 006 | metra_user_profiles, registration_requests, registration_audit_events, station_audit_log |
| 007 | permission_grant_audit, authority_access_audit_events + append-only triggers |
| 008 | indexes |
| seeds/001_isolated_smoke_roles | optional partial roles (not METRA full catalogue) |

### `database/seeds/001_role_catalogue.sql` (authoritative role list)

Roles: observer, station_head, station_auditor, chief_auditor, **network_director**, statistics_director, aftn_operator, system_admin.

### `database/migrations/` 003–031

| # | Name | Kind | Needs (tables) | Creates/Changes | Supabase roles? | Baseline compatibility |
|---|------|------|----------------|-----------------|-----------------|------------------------|
| 003 | station_permission_rpc | RPC | account, station, membership, assignment, roles, grants | function metra_user_has_station_permission | anon/auth/service_role REVOKE/GRANT | OK if baseline + roles adapter |
| 004 | station_catalogue_review_permission | seed allow-list | metra_role_permissions, role **network_director** | INSERT role_permissions | no | OK **only after full role catalogue seed** |
| 005 | station_registration_review_permission | seed | role station_head | INSERT | no | OK with full seed |
| 006 | station_bound_registration_decision | RPC | registration_requests | decide_metra_registration_for_station | yes | OK with baseline registration skeleton |
| 007 | system_registration_review_permission | seed | system_admin | INSERT | no | OK with full seed |
| 008–011 | registration read models / directory | RPC + seed | profiles, registration_*, assignments | functions + inserts | yes | OK with baseline |
| 012–014 | assignment workflow + station audit read | RPC | station_audit_log, assignments | functions + audit inserts | yes | OK with baseline |
| 015–019 | authority-scoped RPC harden | RPC | same core | replace functions | yes | OK |
| **020** | authority membership & grant lifecycle | **DDL+RPC** | permission_grants without authority_id assumed | **ADD COLUMN authority_id**, audit table, RLS, replace station permission fn | yes | **CONFLICT** with baseline (column already present) |
| 021 | authority permission grant lifecycle | RPC | grants, memberships | functions | partial | OK after 020-shaped schema |
| **022** | harden revocation + audit index | DDL | expects constraint permission_grants_revocation_check | DROP constraint | | **CONFLICT** if constraint never created |
| 023–026,028–029 | access decisions / queues / catalogue RPCs | RPC | memberships, grants, authorities | replace/create functions | yes | Mostly OK |
| **027** | authority catalogue read model | RPC | expects **a.authority_code** on authorities | function | yes | **CONFLICT** — baseline has `code` not `authority_code` |
| 030–031 | archive proposals | markers | — | SELECT only | no | OK |

### `supabase/migrations/`

| File | Purpose | Baseline? |
|------|---------|-----------|
| 20261103164003_… | **CREATE metra_observations + observation audit** + submit RPC | **Not in baseline** (single source of truth) |
| 20261103164045_… | deny client access / RLS | Supabase-specific |
| 20261103164638_… | FK indexes | after observations exist |
| 20261103215400_… | observation decision RPC | needs 003 permission fn |
| 20261103220500_… | null hardening | incremental |

---

## 2. Conflict analysis (no silent rewrite)

### Migration 004
- Inserts allow-list for **`network_director` → stations.catalogue.review**.
- Official METRA roles live in `database/seeds/001_role_catalogue.sql` (includes network_director).
- Baseline smoke seed only had observer/station_head → false failure.
- **Resolution design:** empty-DB path must apply **full role catalogue seed**, not invent roles. No random roles.

### Migration 020
- Starts with `ALTER TABLE permission_grants ADD COLUMN authority_id uuid` then NOT NULL + FK + exclusion constraint.
- Written for **hosted schema that lacked authority_id**.
- Baseline **already defines authority_id** (and station_id) because ArchiveRead design needs station binding and authority scoping is established product direction.
- **Effect if applied after baseline:** ERROR column already exists (live evidence).
- **Proposed compatibility (awaiting approval, not applied):**
  - Option A: change 020 to `ADD COLUMN IF NOT EXISTS` + conditional backfill/NOT NULL (upgrade path).
  - Option B: keep 020 pure for hosted upgrades; empty-DB path skips 020 DDL section via a split file (more invasive).
  - RPCs inside 020 that replace `metra_user_has_station_permission` still bind grants by **authority_id**, not station_id (R4 remains open for ArchiveRead).

### Migration 022
- Drops `permission_grants_revocation_check` that baseline never created → FAIL on empty path.
- **Design:** use `DROP CONSTRAINT IF EXISTS` in a future compatibility patch (approval required).

### Migration 027
- References `a.authority_code`; baseline column is `code`.
- **Design:** either baseline rename/add `authority_code` or patch 027 to `code` / add generated column — **approval required**.

---

## 3. Official build paths (design)

### Path N — New empty PostgreSQL (verification / greenfield)

1. `database/baseline/001`…`008`  
2. `database/seeds/001_role_catalogue.sql` (full METRA roles)  
3. **Local-only** role adapter: `anon`, `authenticated`, `service_role`, `metra_api_runtime` (NOT for hosted identity)  
4. `database/migrations/003`… with **compatibility patches** for 020/022/027 (not yet written)  
5. Optional: `supabase/migrations/*` when testing observation stack (needs RLS/roles)  
6. Schema version table (proposed, not created): `schema_migrations(version, applied_at)`  

### Path H — Hosted Supabase already partially migrated

1. **Do not re-apply baseline**  
2. Apply only pending incremental migrations in order  
3. 020 is meaningful if authority_id missing  
4. Never apply isolated `auth.users` stub  

Paths are **not identical**.

---

## 4. Live isolated evidence (this session)

### Path experiment A (empty DB `metra_c2_a`)

Order: baseline 001–008 → `database/seeds/001_role_catalogue.sql` → local role adapter → all `database/migrations/*.sql`

| Result | Count |
|--------|-------|
| OK | **26** |
| FAIL | **3** (020, 022, 027) |

004 **OK** after full role catalogue seed.

### Archive isolation (`metra_isolated` + `database/isolated/*`)

```
PASS: observer archive A allowed
PASS: observer archive B denied (same authority)
PASS: role-only archive denied
PASS: revoked grant denies archive A
PASS: expired assignment denies archive
PASS: audit update blocked
PASS: audit delete blocked
ALL ARCHIVE ISOLATION TESTS PASSED
```

Endpoint remains **503 fail-closed**. R4 production RPC **not** modified.

### Path B (upgrade simulation)

Not fully simulated against a snapshot of hosted schema (no hosted access). From static review: 020 is the primary upgrade migration for authority_id; re-running baseline on hosted would be unsafe.

---

## 5. CI / .NET

| Item | Status |
|------|--------|
| Job `isolated-archive-authz` in workflow file | Present |
| GitHub Actions run URL | **Not obtained** (no push/credentials in sandbox) |
| dotnet build/test this session | **Not run** (SDK not installed in this environment instance) |

No success claimed without artifacts.

---

## 6. Proposed compatibility work (needs your approval before any edit)

1. **020:** `ADD COLUMN IF NOT EXISTS authority_id` + guard backfill exception only when nulls exist; skip duplicate table create for authority_access_audit_events if exists.  
2. **022:** `DROP CONSTRAINT IF EXISTS permission_grants_revocation_check`.  
3. **027:** align column name `authority_code` vs baseline `code`.  
4. Document Path N runner script under `database/baseline/apply_empty_db.sh` (optional).  
5. Still separate: R4 ArchiveRead station bind on production RPC (031).

---

## 7. Stop

No production migration rewrites performed. No hosted writes. Awaiting approval to implement compatibility patches only.
