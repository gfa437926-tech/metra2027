# METRA transfer-pack review — 2026-11-14

## Scope

Read-only source review of the repository transfer pack on
`work/execution-master-2026-11-14`. No hosted database was contacted by this
review. No export, import, restore, migration, grant, or cutover was executed.

## Branch and PR topology

- Repository: `gfa437926-tech/metra2027`
- Work branch: `work/execution-master-2026-11-14`
- PR: #37 — Draft, open, not merged at the latest PR search snapshot.
- Branch comparison against `main`: 579 commits ahead and 4 behind.
- The branch is therefore not release-ready for merge without reconciliation and
  full review of the divergent history.

## CI evidence — exact SHA limitation

The last fully inspected transfer/Backend/Flutter CI snapshot available in this
review is commit
`257b1a18a2b0c60668b4f6909a4e6fea38401912`:

| Workflow | Run | Result |
|---|---:|---|
| METRA transfer safety and Auth remap tests | 43614080980 | success |
| Backend build | 43614080977 | success |
| Flutter Client CI | 43614080925 | success |
| Flutter C7 CI | 43614080945 | cancelled |

Flutter C7's job completed checkout, Flutter setup and `flutter pub get`, then
was cancelled during `flutter analyze`; `flutter test --concurrency=1` was
skipped. This is not a passing C7 result. These runs must not be represented as
proof for a later branch tip unless that exact SHA is verified again.

## Files reviewed

- `database/transfer/README.md`
- `database/transfer/scripts/05_compare.sh`
- `database/transfer/scripts/06_apply_runtime_grants.sh`
- `database/transfer/sql/assert_empty_application_tables.sql`
- `database/transfer/sql/compare_excluded_data.sql`
- `database/transfer/sql/compare_rowcounts.sql`
- `database/transfer/sql/compare_data_hashes.sql`
- `database/transfer/sql/compare_extensions.sql`
- `database/transfer/sql/compare_objects.sql`
- `database/transfer/sql/compare_acl_inventory_acceptance.sql`
- `database/transfer/tests/assert_target_default_acl.sql`

## Review observations

1. `05_compare.sh` requires both source and target refs and validates each URL
   against its project ref before connecting. It performs exact table row counts,
   content fingerprints, Auth-FK cardinality checks, sequence-state checks,
   object fingerprints, ACL acceptance comparison, extension inventory
   comparison, station-catalogue provenance comparison, and a target-side
   assertion that excluded observation history is empty.
2. Extension comparison uses the complete
   `extname|extversion|schema` row. The source inventory must therefore match
   the target on extension name, version and schema; extra target extensions
   are tolerated by the current missing-source-entry check.
3. The structural fingerprint includes application relations, columns,
   functions/procedures, types, constraints, triggers, RLS flags and policy
   expressions. It is not a byte-for-byte database comparison.
4. The ACL acceptance query is intentionally distinct from the full source ACL
   inventory because the target is designed to have tighter default privileges.
   The target default-ACL assertion separately rejects implicit PUBLIC,
   anon/authenticated and inappropriate private-schema grants.
5. The empty-target guard and excluded-observation check are separate controls:
   import is blocked when application tables already contain rows, and the
   acceptance check requires the excluded observation-history table to remain
   empty on the target.

## Outstanding verification

- Re-run or otherwise obtain a completed Flutter C7 analyze + test result on the
  exact current PR head.
- Re-fetch PR #37 head SHA and all associated workflow runs before making any
  current-head CI claim.
- Complete a clean-room disposable PostgreSQL restore drill and verify all
  comparison outputs; repository source inspection alone does not prove a live
  restore.
- Obtain a specifically named, owner-approved new target project before any
  target connection or restore.
- Review the branch's 4-commit divergence from `main` and reconcile the 579
  ahead commits before merge consideration.

## Explicit non-actions

- No Supabase project was contacted.
- No legacy database was accessed.
- No real observation history or Auth users were exported or copied.
- No station catalogue entries were approved or modified.
- No migration, DDL, DML, grant, or production deployment was applied.
- No merge was performed.

## Acceptance boundary

This report records a source review and CI snapshot only. It is not a restore
acceptance, security sign-off, release approval, or authorization to execute
the transfer pack against a hosted project.
