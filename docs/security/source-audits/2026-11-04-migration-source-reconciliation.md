# Supabase migration source reconciliation

Audit date: 2026-11-04  
Target project: `tbdnklyxjvbrilvnwgmq`  
Repository: `gfa437926-tech/metra-weather-intelligence2026`, branch `main`

## Findings

- Database migration history contains **57** applied migrations.
- At the time of the original 2026-11-04 audit, the repository contained **24** SQL migration files.
- A follow-up repository-only comparison on 2026-11-10 found **51** migration SQL files on `main`.
- Of the 33 missing versions listed in the original audit, **27** now have same-name source files in the current tree and **6** remain absent.
- This follow-up did not query the hosted migration ledger; it compares the current repository against the historical 2026-11-04 missing-version list. Treat the six items below as outstanding recovery candidates pending fresh read-only ledger reconciliation.

This is a migration-source drift issue. It does not mean the database schema is absent; the database currently has the applied objects. It means the repository is not a complete reproducible history of how the database reached its current state.

## Filename mismatch

None. The migration source filename was aligned with the database history in commit `c563187b509190b254038d1aa8a358b6ff7a0c12`.

## Outstanding source recovery candidates as of 2026-11-10

The following six versions were listed as applied-but-missing in the 2026-11-04 database inventory and are still absent by filename from the current `main` branch:

- `20261102172226_create_provenance_preserving_observation_store.sql`
- `20261103122944_grant_runtime_station_coordinate_read.sql`
- `20261103123005_link_membership_and_assignment_roles.sql`
- `20261103123127_index_role_catalogue_foreign_keys.sql`
- `20261103162707_enforce_explicit_role_permission_allowlist.sql`
- `20261103162738_seed_conservative_observation_role_permissions.sql`

## Safe recovery plan

1. Preserve the current database as the source of truth; do not reset it.
2. Recover exact SQL from Git history, prior deployment artifacts, local developer copies, or trusted migration backups.
3. Where exact source cannot be recovered, reconstruct a clearly labelled baseline from current catalog definitions (tables, constraints, indexes, policies, triggers, functions, grants) and mark it as reconstructed rather than original.
4. Compare reconstructed definitions against the live database before committing.
5. Never reapply historical migrations merely to populate source files; their effects are already recorded in the database.
6. After recovery, verify a clean migration inventory and test the complete migration chain against a disposable Supabase branch/database before any production deployment.

## Additional source recovery completed on 2026-11-04 and subsequent repository updates

- The prior repository's `database/migrations` directory contained the source SQL for applied migrations `003` and `005` through `014`; these eleven files were restored to this repository using the exact version/name recorded in the new database. Subsequent commits restored additional source files, bringing the current repository inventory to 51 files.
- The corresponding live function definitions were inspected, and the authorization functions were confirmed non-executable by `anon` and `authenticated` and executable by `service_role` only. The role-permission rows introduced by these migrations were also confirmed present.
- The prior repository's `supabase/migrations` directory contains five observation migration sources, all already restored. Its migration directories contain no further source files for the remaining 33 missing migrations.

## Guardrails

- No historical migration was replayed during this audit. One new forward-only registration eligibility migration was applied and recorded as `20261104042128`.
- Five observation workflow migrations and eleven station/permission workflow migrations were recovered from the prior METRA repository (including its `database/migrations` directory) and restored under the exact version/name recorded in the new database. The recovered functions, execution privileges, and role-permission allow-list entries were checked against the live database at that time. Some current files explicitly describe themselves as reconstructed from already-applied migrations; their byte-for-byte identity with original deployed sources is not established by this repository audit. The new registration eligibility migration `20261104042128_require_approved_active_station_for_registration` is applied and its exact SQL source is committed.

## Follow-up inventory comparison on 2026-11-10

- Current `main` contains 51 SQL migration files.
- 27 of the 33 versions previously listed as missing now have same-name files.
- Six outstanding source candidates are listed above.
- No hosted database was queried or modified during this follow-up; no migration was replayed.
- The legacy database was not accessed or changed.
