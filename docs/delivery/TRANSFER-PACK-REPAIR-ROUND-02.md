# METRA 2027 — Transfer pack repair round 02

- Date: 2026-11-14
- Branch: `work/execution-master-2026-11-14`
- Head at report update: `257b1a18a2b0c60668b4f6909a4e6fea38401912`
- PR #37: Draft, mergeable, not merged
- Source project: `tbdnklyxjvbrilvnwgmq` only
- Target project: not yet named or created

## 1. What was actually implemented

### Transfer package

1. Source URL guard permits only the approved experimental project and validates direct Supabase hosts or matching Supavisor usernames. Known legacy project refs are refused.
2. Encrypted GPG AES-256 export for application `public/private` schema and data, with a manifest and SHA-256 checksums.
3. Exact ten-file checksum manifest verification; rejects tampered files, missing/duplicate entries, unexpected files, and path traversal.
4. Required-extension installer reads the source inventory, installs missing extensions in their recorded schemas, and verifies exact versions and schemas.
5. Schema/data import requires a new, identified, empty target and validates the full manifest before writing.
6. Exact comparison covers row counts, non-Auth-FK data hashes, Auth-FK row/null/distinct counts, sequence state, object inventory, extensions, station provenance, and reviewed object grants.
7. Importer integration test runs against a disposable PostgreSQL database and verifies both a successful data import and rejection of excluded observation rows.

### Target-only security hardening

The source Supabase project was not changed. The target restore scripts now intentionally improve on broad source defaults:

- Public default privileges: only server-side `service_role` receives implicit table, sequence, and function privileges.
- Private default functions: only `metra_api_runtime` receives implicit EXECUTE.
- `PUBLIC`, `anon`, and `authenticated` receive no implicit default privileges.
- Client roles receive no sequence privileges.
- Audit trigger functions are not directly executable by client roles; their immutability triggers are tested after privilege tightening.
- Audit trigger functions are pinned to `search_path=pg_catalog`.
- Full source ACL inventory is retained for audit; comparison uses a separate reviewed acceptance inventory and explicit target-default-ACL assertions.

### Main files

**Added**
- `database/transfer/scripts/02_install_required_extensions.sh`
- `database/transfer/sql/compare_sequence_state.sql`
- `database/transfer/sql/compare_acl_inventory_acceptance.sql`
- `database/transfer/tests/assert_target_default_acl.sql`
- `database/transfer/tests/assert_target_function_search_path.sql`
- `database/transfer/tests/test_install_extensions.sh`
- `database/transfer/tests/test_import_data.sh`
- `database/transfer/tests/test_checksums.sh`

**Changed**
- `scripts/lib/project_url_guard.sh`, `00_preflight.sh`, `01_export_source.sh`, `02_bootstrap_target.sh`, `03_import_schema.sh`, `04_import_data.sh`, `05_compare.sh`, `06_apply_runtime_grants.sh`.
- `sql/bootstrap_target_roles.sql`, `sql/apply_runtime_grants.sql`, runtime grant fixtures and assertions.
- `.github/workflows/transfer-auth-remap.yml` and transfer-pack workflow.
- README, restore guide, cutover checklist, and delivery reports.

## 2. Read-only Supabase source findings

The read-only audit is recorded in `docs/delivery/SUPABASE-READONLY-READINESS-2026-11-14.md`.

- Project status: active/healthy; region `eu-west-2`; PostgreSQL `17.11.0.016`.
- 23 public application tables.
- `auth.users`: 0 rows; 44 Auth foreign keys, all validated.
- `metra_observation_records`: 58,059 rows, all non-demo; 1,251 lack `station_id`. All observation rows (demo and non-demo) are excluded from this transfer.
- `station_catalogue`: 65 rows (3 demo, 62 non-demo); all 65 are pending approval. No approval state is changed.
- `station_coordinates`: 50 current rows; 15 stations lack current coordinates; 0 orphan rows and 0 duplicate current station links.
- All 23 public application tables have RLS enabled. Four equipment/support tables have no RLS policies and no anon/authenticated table grants; they remain server-only/default-deny.
- Source public default ACLs are broad. Target scripts deliberately tighten them.
- Two mutable search-path warnings are addressed in the target scripts.
- Ten unindexed-FK recommendations remain proposed, not applied. Forty-six unused-index notices were not used to justify dropping indexes.
- No health-advisor findings were returned.

## 3. CI results

- **METRA transfer safety and Auth remap tests — PASS**, run `43614080980`: ShellCheck, Python remapper tests, shell guards, checksum manifest, extension installer, PostgreSQL ACL/default-ACL/search-path/trigger tests, Auth-FK and sequence checks, station provenance, and end-to-end data importer.
- **Backend build — PASS**, run `43613918109`: NuGet advisory gate, API build, domain/API tests, production container build, and three isolated PostgreSQL contract suites.
- **Flutter Client CI — PASS**, run `43614080925`: Flutter dependency resolution, analyze, and Flutter tests.
- **Flutter C7 CI — PENDING**, run `43614080945`; no result is claimed yet.

Earlier failures were fixed and rerun: ShellCheck SC2164, station-provenance fixture columns, importer manifest fixture flags, and the station-review JsonElement parser/test contract.

## 4. What was not executed

- **Not executed:** live `pg_dump` export from the source; no secure `METRA_SRC_DATABASE_URL` was available in this runtime.
- **Not executed:** target project creation/selection; the new target ref has not been provided.
- **Not executed:** schema/data import into a hosted target.
- **Not executed:** Auth user migration; source currently contains zero Auth users.
- **Not executed:** full restore drill, target application smoke tests, cutover, or production deployment.
- **Not executed:** approval of the 65 pending stations or creation of the 15 missing coordinates.
- **Not executed:** application of the ten proposed FK indexes.
- **Not executed:** merge of PR #37 into `main`.

No Supabase schema, data, policy, grant, extension, or project setting was changed. All Supabase inspection in this round was read-only. No legacy METRA database was accessed.

## 5. Main-branch correction

A documentation-only DB-advisor proposal was briefly committed to `main` because a file-create request omitted the work-branch parameter. It was copied to the work branch and removed from `main` with a revert commit. The proposal is present on the work branch and absent from the current `main` tree. No application code or database was changed by that incident; the add/revert commits remain in Git history.

## 6. Remaining steps

1. Obtain the final Flutter C7 CI result.
2. Review the ten unindexed-FK recommendations and decide whether to include the proposed indexes in the new-target migration.
3. Resolve the 15 missing station coordinates only from authoritative source material; otherwise preserve the gaps and pending station states.
4. Create/name the new Supabase target project and provide connection details through a secure secret manager (never in chat or Git).
5. Run source preflight and encrypted export; verify the exact artifact set and SHA-256.
6. Install required extensions, bootstrap restrictive roles/default ACLs, import schema/data, and apply runtime grants.
7. Run source-target comparisons, configure target Auth independently, and perform .NET/Flutter staging smoke tests.
8. Complete a separate restore drill and owner acceptance before any cutover or merge.

## 7. Progress

- Transfer-pack implementation and isolated validation: **approximately 90%**; the remaining Flutter C7 workflow is pending.
- Live database migration: **0%**; no target project or live export/import has occurred.
- Overall METRA project percentage: **not recalculated** in this transfer-focused round.

The work is not complete. The next execution point is step 1 above, followed by the target-project/export/restore gates.
