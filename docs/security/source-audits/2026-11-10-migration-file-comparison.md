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
