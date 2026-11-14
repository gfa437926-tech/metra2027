# METRA 2027 — Stage C2.2 Final Compatibility Audit

**Branch:** `work/backend-db-integration-phase`  
**Base commit reviewed:** `36db4d9f4e27ff37ce54b73633f6c6a66abb610b`  
**Follow-up commit (this audit + 020 NOT NULL tighten):** see git log after this file lands.

## 1. Patch 020 — `authority_id` equivalence

| Attribute | Baseline `005` (before Path N compat) | Original migration 020 | Path N after compat |
|-----------|----------------------------------------|------------------------|---------------------|
| Type | `uuid` | `uuid` | `uuid` |
| Nullable | **YES** (optional at CREATE) | Added nullable then **SET NOT NULL** after empty check | **NO** (compat now SET NOT NULL when no null rows) |
| Default | none | none | none |
| FK | `REFERENCES meteorological_authorities(id) ON DELETE RESTRICT` | same + named `permission_grants_authority_fk` | FK present, confdeltype **RESTRICT (`r`)** |
| ON UPDATE | default | default | default |
| Indexes | baseline indexes on grants | `permission_grants_authority_user_permission_idx` (+ gist exclusion in 020) | Path N applies remaining 020 objects via compat (skip ADD COLUMN) |
| Functions using column | N/A at baseline | `metra_user_has_station_permission` joins `g.authority_id` | Same functions installed by compat body |

**Gap found in C2.1:** Path N left `authority_id` nullable while 020 end-state is NOT NULL.  
**C2.2 fix (compat only):** if any null → raise `permission_grants_authority_backfill_required`; else `ALTER … SET NOT NULL`.  
**Verified:** both `metra_c22_a` and `metra_c22_b` report `is_nullable = NO`.

Original `database/migrations/020_*.sql` **unchanged**. Path H still uses original file when column absent.

## 2. Patch 022 — revocation check

| Item | Original 022 | Path N compat |
|------|--------------|---------------|
| Expression | `CHECK (revoked_at IS NULL OR revoked_at >= created_at)` | **Identical** (`pg_get_constraintdef`) |
| Accept | `revoked_at` NULL; or `revoked_at >= created_at` | Live: revoke with `now()` allowed |
| Reject | `revoked_at < created_at` | Live: **PASS** check_violation |
| Functions | `revoke_authority_membership` / grant revoke (022 body) | Extracted to `022_path_n_revocation_functions.sql` |
| Index | `authority_access_audit_actor_time_idx` | `CREATE INDEX IF NOT EXISTS` |

No structural hide via empty DROP: constraint is **added if missing** with full expression.

## 3. Patch 027 — `authority_code`

| Consumer search | Result |
|-----------------|--------|
| Baseline | Had `code`; Path N compat **renames** to `authority_code` (no dual column) |
| Migration 027 | JSON key `authority_code` from column `a.authority_code` |
| supabase/migrations | No `authority_code` dependency found in observation files |
| Backend .NET | No hard-coded `authority_code` / column mapping found for this field |
| Live columns | `authority_code`, `is_national` present; **`code` absent** |

## 4. Runner audit (`path_n_apply.sh`)

- Order: baseline 001–008 → official role seed → local role adapter → 027 compat → migrations loop → optional observations if `PATH_N_APPLY_OBSERVATIONS=1` (default **off**).
- Skips **only** `020_*` and `022_*` originals; substitutes compat.
- `set -euo pipefail` + `ON_ERROR_STOP=1` → fail-fast.
- Path H documentation: do **not** run this script against hosted; use original migrations.

## 5. PostgreSQL tests — two empty DBs

| Check | metra_c22_a | metra_c22_b |
|-------|-------------|-------------|
| Path N apply exit | **0** | **0** |
| public tables | 16 | 16 |
| role catalogue count | 8 | 8 |
| authority_id type/null | uuid / **NO** | uuid / **NO** |
| FK RESTRICT | yes | yes |
| archive station CHECK | yes | yes |
| revocation CHECK expr | match 022 | match 022 |
| authority_code only | yes | yes |
| archive null station reject | PASS | PASS |
| revoked_at < created_at reject | PASS | PASS |
| revoke allowed when valid | PASS | PASS |
| authority audit UPDATE | blocked (append-only trigger) | blocked |

**Isolated archive suite** (`database/isolated/02_*`): **ALL ARCHIVE ISOLATION TESTS PASSED**.

## 6. CI & .NET

| Item | Status |
|------|--------|
| Workflow jobs `isolated-archive-authz`, `path-n-empty-db` | Present in repo |
| Live GitHub Actions URL | **Unavailable** (no authenticated push/API from this sandbox) |
| `dotnet build` / `dotnet test` | **Not executed** this session (SDK not installed in environment) |

**Do not claim CI or test suite green without artifacts.**

## 7. Residual risks

1. Gist exclusion constraint `permission_grants_no_overlapping_periods` from 020 may not be fully mirrored on every Path N run if 020 DDL section skipped partially — monitor when enabling heavy grant concurrency tests.
2. R4: production RPC still authority-scoped for grants; ArchiveRead station bind is table CHECK + isolated predicate + Domain; production RPC 031 still proposal-only.
3. Observation tables not in default Path N (`PATH_N_APPLY_OBSERVATIONS` off).

## 8. Constraints honored

No hosted Supabase, no METRA OLD, no original migration edits, no RPC 031, archive API **503**, no Flutter/Angular, no PR merge.
