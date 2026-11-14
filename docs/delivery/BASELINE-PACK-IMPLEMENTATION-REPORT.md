# METRA 2027 — Baseline pack implementation report

**Branch:** `work/backend-db-integration-phase`  
**Parent:** `b33b0a36c1df2f3e0776ca69d49660a65e51cd25`  
**Scope:** Create `database/baseline/` + isolated verification only.

## 1. New files

| Path | Role |
|------|------|
| `database/baseline/README.md` | Apply order, observation source of truth, ArchiveRead design notes |
| `database/baseline/001_extensions_and_schemas.sql` | pgcrypto, schemas |
| `database/baseline/002_identity_stub.sql` | `auth.users` **stub** (isolated only) |
| `database/baseline/003_org_and_stations.sql` | countries, authorities, station_catalogue |
| `database/baseline/004_roles_and_permission_catalogue.sql` | roles, permissions, role_permissions |
| `database/baseline/005_memberships_assignments_grants.sql` | accounts, memberships, assignments, grants + **CHECK archive requires station_id** |
| `database/baseline/006_registration_and_station_audit.sql` | profiles, registration_*, station_audit_log |
| `database/baseline/007_audit_append_only.sql` | grant/authority/registration/station audit + immutability triggers |
| `database/baseline/008_indexes.sql` | core indexes |
| `database/baseline/seeds/001_isolated_smoke_roles.sql` | optional observer/station_head smoke roles only |

**Not in baseline (by design):** `metra_observations`, `metra_observation_audit_events` — authoritative CREATE remains in `supabase/migrations/20261103164003_…` to avoid duplicate definitions.

## 2. Observation source of truth

- **Canonical:** `supabase/migrations/20261103164003_create_operational_observation_submission.sql`
- Baseline does **not** redefine those tables.
- API contracts unchanged; archive endpoint remains **503 fail-closed**.

## 3. ArchiveRead in baseline (table-level only)

`permission_grants` constraint:

```sql
CONSTRAINT permission_grants_archive_requires_station CHECK (
  permission_code <> 'observation.archive.read' OR station_id IS NOT NULL
)
```

- Does **not** modify production RPC 003/020.
- Does **not** backfill data.
- Does **not** generalize the constraint to all permissions.

## 4. Live PostgreSQL results

### Baseline apply from empty (twice)

- Databases: `metra_baseline_a`, `metra_baseline_b`
- All `001`–`008` + smoke seed: **BASELINE_OK** both times
- 16 public tables listed after apply

### Constraint / audit smoke

```
PASS: archive grant without station_id rejected
PASS: permission_grant_audit update blocked
```

### Isolated archive suite (existing scripts)

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

### Migrations after baseline (sample)

| File | Result | Note |
|------|--------|------|
| 003_station_permission_rpc | **OK** | Function creates on baseline tables |
| 004_…catalogue_review_permission | FAIL | Inserts `network_director` role not in smoke seed |
| 020_authority… | FAIL | `authority_id` already exists on `permission_grants` (baseline includes column; 020 assumes add) |
| 030 / 031 proposals | **OK** | SELECT-only markers |

**Conflict meaning:** incremental migrations were written against a pre-existing hosted shape; baseline closes the empty-DB gap for **core tables**, but full linear replay of every 004–029 file still needs a dedicated compatibility pass (role seed completeness, IF NOT EXISTS column adds). Documented — not silently “fixed” by rewriting production migrations in this step.

## 5. CI / .NET

| Item | Status |
|------|--------|
| Workflow job `isolated-archive-authz` | Present in `.github/workflows/backend-ci.yml` (from prior commit) |
| Live GitHub Actions run URL | **Not available in this sandbox** (no push credentials / no Actions API) |
| `dotnet test` this session | **Not run** — .NET SDK path not available after environment reset |
| Prior session | `Metra.Api` Release **build succeeded**; full test host timed out |

Do **not** claim CI green without a run URL.

## 6. Tables deliberately omitted from baseline

- Forecast / AI / Climatol / notifications — no approved operational schema
- Full electronic-record warehouse beyond station/observation/grant audits
- `metra_observations*` — owned by supabase migrations
- Supabase platform roles as first-class baseline objects (optional local adapter only when replaying migrations)

## 7. Decisions still needing approval

1. Compatibility migration to make 004–029 replay cleanly after baseline (role seed + conditional DDL).
2. Production RPC station bind for ArchiveRead (031) + backfill.
3. Any hosted apply of baseline or migrations.
4. Flutter integration stage.

## 8. Constraints honored

No hosted Supabase writes, no METRA OLD, no production RPC apply, no archive enablement, no Flutter mock removal, no Angular, no PR merge.
