# METRA 2027 — Stage C2.1 Path N compatibility patches

**Branch:** `work/backend-db-integration-phase`  
**Parent:** `7b638255a2846f84347c90b1b20156ac72f39e7d`

## Constraint

Original files under `database/migrations/` and `supabase/migrations/` were **not modified**.

## Compat patches (`database/baseline/compat/`)

| Patch | Original | Reason | Detection | Path H |
|-------|----------|--------|-----------|--------|
| `020_path_n_skip_add_authority_id.sql` | 020 | Baseline already has `authority_id`; original `ADD COLUMN` fails | Skip original when Path N | Apply original 020 if column absent |
| `022_path_n_revocation_check.sql` + `022_path_n_revocation_functions.sql` | 022 | Original `DROP CONSTRAINT` fails if missing; business rule `revoked_at IS NULL OR revoked_at >= created_at` must remain | Skip original 022 | Apply original 022 |
| `027_path_n_authority_code_column.sql` | 027 | Official catalogue JSON field is `authority_code`; baseline had `code` | Rename `code`→`authority_code` if needed; add `is_national` | No-op if already aligned |

Runner skips **original** 020 and 022 on Path N only; applies compat instead.

### 027 naming decision
- **Official name for Path N / read-model JSON:** `authority_code`
- Not a second parallel column; rename when `code` exists
- Backend C# does not hardcode this column name

### 022 constraint decision
- Keep business rule; add constraint if absent (not silent drop-only)

## Path N runner

`database/baseline/path_n_apply.sh`

Order: Baseline 001–008 → role catalogue seed → local role adapter → 027 column compat → migrations with 020/022 skips → optional supabase observation migrations if `PATH_N_APPLY_OBSERVATIONS=1`.

Stops on first error (`ON_ERROR_STOP`).

## Live results

| Database | Result |
|----------|--------|
| `metra_path_n1` | **Path N schema apply completed successfully** (exit 0) |
| `metra_path_n2` | **Path N schema apply completed successfully** (exit 0) |

Verified on `metra_path_n1`:
- constraints: `permission_grants_archive_requires_station`, `permission_grants_revocation_check`
- columns: `authority_code`, `is_national` (no leftover requirement for dual `code`)

Archive isolation suite on `metra_isolated`: **ALL ARCHIVE ISOLATION TESTS PASSED**

## CI

- Kept `isolated-archive-authz`
- Added job `path-n-empty-db` to `.github/workflows/backend-ci.yml`
- **No GitHub Actions run URL** from this environment (cannot claim Actions green)

## .NET

Not executed this session (SDK not present). Do not claim test success.

## Not done (by design)

- Production RPC 031 / R4
- Hosted apply
- Flutter / Angular
- Backfill
