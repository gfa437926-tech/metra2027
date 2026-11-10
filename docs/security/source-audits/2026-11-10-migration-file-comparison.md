# METRA migration file comparison — repository-only

Date: 2026-11-10

Repositories compared:
- Target: `gfa437926-tech/metra2027`, main
- Source: `gfa437926-tech/metra-weather-intelligence2026`, main

No database was connected to, queried, or modified. This report compares tracked SQL files only; it does not establish what is currently installed in any hosted database.

## Inventory

- Target repository: 33 tracked `.sql` files across `database/` and `supabase/migrations/`.
- Source repository: 52 tracked `.sql` files under `supabase/migrations/`.
- Three observation migration files have identical paths and Git blob SHA in both repositories:
  - `20261103164003_create_operational_observation_submission.sql`
  - `20261103164045_deny_client_access_to_operational_observations.sql`
  - `20261103164638_index_operational_observation_foreign_keys.sql`

## Timestamped source migrations already represented in target database migrations

The following source files are byte-for-byte identical to the corresponding target files, despite different filenames/paths:

| Source file in second repository | Existing target file | Result |
|---|---|---|
| `20261103025556_003_add_station_permission_check.sql` | `database/migrations/003_station_permission_rpc.sql` | Identical |
| `20261104031431_005_station_registration_review_permission.sql` | `database/migrations/005_station_registration_review_permission.sql` | Identical |
| `20261104031432_006_station_bound_registration_decision.sql` | `database/migrations/006_station_bound_registration_decision.sql` | Identical |
| `20261104031434_007_system_registration_review_permission.sql` | `database/migrations/007_system_registration_review_permission.sql` | Identical |
| `20261104032044_008_registration_review_read_models.sql` | `database/migrations/008_registration_review_read_models.sql` | Identical |
| `20261104032342_009_secure_registration_submission_and_status.sql` | `database/migrations/009_secure_registration_submission_and_status.sql` | Identical |
| `20261104033138_010_station_user_directory_read_model.sql` | `database/migrations/010_station_user_directory_read_model.sql` | Identical |
| `20261104033144_011_station_user_directory_permission.sql` | `database/migrations/011_station_user_directory_permission.sql` | Identical |
| `20261104033839_012_station_assignment_workflow.sql` | `database/migrations/012_station_assignment_workflow.sql` | Identical |
| `20261104034246_013_station_assignment_revocation.sql` | `database/migrations/013_station_assignment_revocation.sql` | Identical |
| `20261104035035_014_station_audit_read_model.sql` | `database/migrations/014_station_audit_read_model.sql` | Identical |

The source file `20261104030506_004_station_catalogue_review_permission.sql` is not byte-identical to `database/migrations/004_station_catalogue_review_permission.sql`, but both contain the same INSERT ... ON CONFLICT DO NOTHING statement for the `network_director / stations.catalogue.review` role-permission row. Their comments differ. The source copy explicitly labels itself reconstructed source for an already-applied migration; keep the target's existing file and do not replace it with the reconstructed copy.

## Critical tracked-source gap: metra_role_permissions

A scan of all 33 tracked SQL files in the target repository found references to `public.metra_role_permissions` in the station authorization RPC, role-permission insert migrations, and authority-access workflows, but no tracked `CREATE TABLE public.metra_role_permissions` statement.

The target's `docs/security/role-permission-matrix.md` also describes the table as a required authorization source. The second repository's audit reports that the original role-permission allow-list and seed migration sources remain unrecovered.

This is a repository-source gap, not proof that the table is absent from the hosted NEW database. It must be reconciled against an approved schema export or trusted migration artifact before any staging test or migration plan is finalized. Do not invent an original migration, create the table, or apply SQL as part of this consolidation.

## Non-identical / source-only files

The source repository has numerous foundational and historical migrations not present under the same filename in the target repository, including station catalogue creation/integrity, identity membership/account lifecycle, registration workflow and approval, least-privilege runtime role, and permission-check logic.

The target has its own later authority lifecycle migrations and a separate `database/migrations/` sequence. Filename differences alone cannot prove whether the source-only migration's effects are:
- already represented by a different target migration;
- part of an earlier baseline that was provisioned outside tracked migrations;
- genuinely missing from the target source history; or
- obsolete/superseded.

Therefore none of the remaining source-only SQL files is approved for copying or replay by this report. Each must be mapped to schema objects, dependencies, chronology, and exact SQL effects in a separate read-only reconciliation matrix.

## Recommended disposition

1. Keep the three same-path identical observation migrations only once in the target.
2. Keep the 11 byte-identical numbered workflow equivalents in the target's `database/migrations/`; do not copy timestamped duplicates from the source.
3. Keep target migration 004; preserve the source's reconstructed copy only as provenance evidence if needed.
4. Do not bulk-copy any remaining source-only migration.
5. Resolve the tracked-source gap for `metra_role_permissions` using a trusted schema/migration artifact and explicit user approval before any database inspection or SQL action.
6. Preserve all migration histories in both Git repositories until the full reconciliation is accepted.

## Safety

No SQL was executed, no migration was replayed, no database was connected to, no staging state was inspected, and no files or repositories were deleted.


## Detailed source-only reconciliation — 2026-11-10

A second inventory compared the 52 source migration filenames/blob SHAs with the target's 29 numbered `database/migrations` files and 5 `supabase/migrations` files. In addition to the 11 exact numbered workflow equivalents and 5 observation equivalents described above, the source file `20261104030506_004_station_catalogue_review_permission.sql` has a target counterpart with the same INSERT/ON CONFLICT statement but different comments; retain the target file and do not replace it.

The following 35 source migrations have no byte-identical same-effect counterpart identified by the tracked-file comparison. This is a **source-only inventory**, not a finding that all their effects are absent from the target database. Each remains unapproved for copying until object/dependency/chronology mapping is complete:

### Station catalogue and identity foundation

- `20261102154652_create_independent_station_catalogue.sql`
- `20261102155101_index_station_catalogue_foreign_keys.sql`
- `20261102155110_add_catalogue_integrity_triggers.sql`
- `20261102155119_lock_station_catalogue_client_access.sql`
- `20261102163034_enforce_station_temporal_integrity.sql`
- `20261102165436_add_identity_membership_and_station_assignment.sql`
- `20261102165505_lock_identity_tables_and_index_foreign_keys.sql`
- `20261102165724_add_user_profile_and_align_account_lifecycle.sql`
- `20261102165758_index_account_state_requester.sql`
- `20261102171030_add_station_source_provenance_and_demo_flags.sql`
- `20261102171037_support_unverified_station_operational_status.sql`

### Registration lifecycle and runtime grants

- `20261102235913_create_registration_workflow_persistence.sql`
- `20261102235937_add_atomic_registration_submission_rpc.sql`
- `20261103000038_harden_registration_idempotency_checks.sql`
- `20261103000332_provision_least_privilege_api_runtime_role.sql`
- `20261103000835_add_atomic_two_stage_registration_approval.sql`
- `20261103000914_grant_runtime_registration_queue_read.sql`
- `20261103001045_harden_registration_approval_expected_state.sql`
- `20261103001209_grant_runtime_registration_audit_read.sql`
- `20261103001354_use_database_clock_for_registration_approval.sql`
- `20261103001407_move_registration_submission_rpc_to_private_schema.sql`
- `20261103001654_revoke_public_execute_from_approval_rpc.sql`
- `20261103001743_drop_obsolete_registration_approval_rpc.sql`
- `20261103001942_classify_existing_pending_registration_before_linked_account.sql`
- `20261103002006_fix_pending_registration_replay_classification.sql`
- `20261103010120_respect_scheduled_permission_revocation.sql`
- `20261103010435_add_registration_foreign_key_indexes.sql`

### Authenticated registration and catalogue review hardening

- `20261104014631_registration_authenticated_entrypoint.sql`
- `20261104014827_registration_server_timestamp_and_terms_guard.sql`
- `20261104015029_authenticated_registration_decision_entrypoint.sql`
- `20261104015823_restrict_registration_rpc_to_server_runtime.sql`
- `20261104021613_20261104110000_secure_station_catalogue_review.sql`
- `20261104024652_harden_station_catalogue_review_null_validation.sql`
- `20261104042128_require_approved_active_station_for_registration.sql`
- `20261110120000_honor_scheduled_permission_revocation.sql`

### Separate six historical recovery candidates

The six filenames listed in `2026-11-10-authorization-audit-followup.md` are not present in the 52-file source inventory at all. They are therefore a distinct recovery problem, not six more files to copy from the source tree. In particular, `20261103162707_enforce_explicit_role_permission_allowlist.sql` and `20261103162738_seed_conservative_observation_role_permissions.sql` are the missing authoritative allow-list sources required to prove the exact permission ceiling. Do not recreate them as purported originals.

### Next reconciliation gate

For each of the 35 source-only files, record: schema objects created/altered, function signatures and bodies, grants/revokes, RLS/policies, triggers/indexes, dependency order, whether a later target migration supersedes it, and whether the effect is part of an externally provisioned baseline. Compare only against an approved read-only schema export of the NEW target or trusted deployment artifacts. The current tracked-source scan alone cannot establish live state. The six historical files require exact-source recovery or a separately labelled reconstructed baseline after explicit approval; no SQL is to be executed as part of this audit.
