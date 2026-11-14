# METRA — Complete approved migration bundle extraction (2026-11-14)

## Source pin and scope

- Repository: `gfa437926-tech/metra2027`
- Recovery branch: `work/metra-full-schema-recovery-2026-11-14`
- Source tree commit inspected: `8750c21d6cfcbc4af3b321dc2b9703610961ff76`
- Scope: `database/baseline/`, `database/migrations/`, `supabase/migrations/`, `database/isolated/`, `database/tests/`.
- No hosted database or legacy database was accessed or modified.

## Extracted file inventory

The recursive Git tree contains **29 numbered SQL files** in `database/migrations/` (003–031) and **5 SQL files** in `supabase/migrations/`. The baseline contains 8 ordered SQL files plus its optional smoke seed and catalog verifier.

### database/migrations (29 files)

| # | File | Classification |
|---:|---|---|
| 003 | `003_station_permission_rpc.sql` | authorization function |
| 004 | `004_station_catalogue_review_permission.sql` | role-permission seed |
| 005 | `005_station_registration_review_permission.sql` | role-permission seed |
| 006 | `006_station_bound_registration_decision.sql` | registration decision function |
| 007 | `007_system_registration_review_permission.sql` | role-permission seed |
| 008 | `008_registration_review_read_models.sql` | read-model functions |
| 009 | `009_secure_registration_submission_and_status.sql` | registration functions |
| 010 | `010_station_user_directory_read_model.sql` | directory function |
| 011 | `011_station_user_directory_permission.sql` | role-permission seed |
| 012 | `012_station_assignment_workflow.sql` | assignment functions and role-permission seed |
| 013 | `013_station_assignment_revocation.sql` | assignment revocation function |
| 014 | `014_station_audit_read_model.sql` | audit read function |
| 015 | `015_authority_scoped_permission_rpc.sql` | authority authorization function |
| 016 | `016_authority_scoped_station_catalogue_review.sql` | authorization and review functions |
| 017 | `017_authority_scoped_system_registration_review.sql` | registration review/read functions |
| 018 | `018_harden_authority_registration_decision_nulls.sql` | hardened registration function |
| 019 | `019_restore_registration_station_binding.sql` | registration binding function |
| 020 | `020_authority_membership_and_permission_grant_lifecycle.sql` | table/column/constraint/index/RLS/function DDL |
| 021 | `021_authority_permission_grant_lifecycle.sql` | permission grant lifecycle functions |
| 022 | `022_harden_authority_access_revocation_and_audit_index.sql` | constraint/index/function DDL |
| 023 | `023_bind_authority_access_decisions_to_route_scope.sql` | function signature replacements |
| 024 | `024_revoke_direct_service_role_writes_to_authority_audit.sql` | privilege changes |
| 025 | `025_require_active_subject_for_authority_approval.sql` | hardened lifecycle functions |
| 026 | `026_add_authority_access_catalogue_read_models.sql` | read-model functions |
| 027 | `027_add_authority_catalogue_read_model.sql` | read-model function |
| 028 | `028_extend_authority_access_queue_with_active_directory.sql` | queue function replacement |
| 029 | `029_include_scheduled_access_in_revocation_directory.sql` | queue function replacement |
| 030 | `030_observation_archive_read_permission_proposal.sql` | proposal marker only; no operational DDL |
| 031 | `031_archive_grant_station_bind_proposal.sql` | proposal marker only; no operational DDL |

### supabase/migrations (5 files)

1. `20261103164003_create_operational_observation_submission.sql`
2. `20261103164045_deny_client_access_to_operational_observations.sql`
3. `20261103164638_index_operational_observation_foreign_keys.sql`
4. `20261103215400_observation_review_decision.sql`
5. `20261103220500_harden_observation_decision_null_validation.sql`

The two proposal-only files 030 and 031 are intentionally not applied as executable schema changes. Their stated security requirements remain acceptance criteria, not an authorization to alter production.

## Canonical object ownership found

- Operational observation tables are created by Supabase migration 20261103164003; do not duplicate them in Baseline.
- The current baseline pack creates the core identity, country/authority/station, role, membership, assignment, grant, registration and audit skeletons.
- The numbered database migrations mostly add or replace routines, permission mappings and lifecycle behavior. They depend on richer pre-existing table shapes than the current baseline skeleton.
- Isolated Stage C bootstrap is a purpose-built test fixture, not the canonical complete schema and not a replacement for the migration chain.

## Blocking incompatibilities — confirmed from source text

A linear empty-database replay must **not** be reported as successful with the current baseline:

1. Baseline 005 already defines `permission_grants.authority_id`; migration 020 issues an unconditional `ADD COLUMN authority_id`.
2. Baseline 007 already creates `authority_access_audit_events`; migration 020 issues an unconditional `CREATE TABLE authority_access_audit_events`.
3. Baseline 006 defines a minimal `metra_user_profiles` with `display_name`; migration 008 reads `first_name`, `father_name`, `last_name`.
4. Baseline 003 defines `station_code`; migration 008 reads `local_station_code`.
5. Baseline 005's `station_assignments` omits fields used by migration 012, including `requested_by`, `reason`, `approved_by`, `reviewed_at`, and `updated_at`.
6. Baseline 006's `station_audit_log` shape differs from migration 012/014 expectations (`entity_type`, `entity_id`, `action`, `actor_id`, `reason`, `before_data`, `after_data`).
7. Baseline 006's `registration_requests` and `registration_audit_events` are minimal skeletons, while migrations 008/009/020 use additional workflow fields such as `phone_snapshot`, `terms_version`, `submitted_at`, `review_note`, `requested_by`, and workflow audit fields.
8. Migrations 004, 007 and later workflow code expect catalogue roles and permission mappings; the optional smoke seed only inserts `observer` and `station_head`. The full approved role seed is `database/seeds/001_role_catalogue.sql`, but permission allow-lists also need an explicitly reviewed seed inventory.

These are not cosmetic. They prevent a safe linear replay until an authoritative schema reconciliation is approved and implemented. Do not paper over them with `IF NOT EXISTS` alone: that would leave the wrong column shape in place.

## Rebuild and comparison status

- Static extraction and source inspection: **complete for the pinned tree**.
- Canonical table/column reconciliation: **not complete**; see blockers above.
- Empty-database replay of all migrations: **not run**, because source inspection proves deterministic conflicts.
- Two-database catalog comparison: **not run**; it must follow a successful compatible rebuild.
- Hosted Supabase: **not touched**.
- Legacy METRA database: **not touched**.
- Main branch: **not touched**.

## Next safe implementation gate

1. Approve one canonical full schema definition for the tables whose baseline and migrations disagree.
2. Replace skeleton-only baseline definitions with the reviewed full definitions (or add a versioned reconciliation layer before migration 003); retain migration ownership for observation tables.
3. Reconcile the role catalogue and every referenced permission code using the reviewed seed as input.
4. Replay the complete chain in two fresh isolated PostgreSQL databases.
5. Export schema-only snapshots and catalog inventories from both databases; require byte-identical normalized snapshots and zero missing objects.
6. Run all SQL contract tests, including archive station-A/station-B isolation and append-only audit tests.
7. Record real command output and CI run links before declaring acceptance.

No hosted apply or production RPC change is authorized by this report.
