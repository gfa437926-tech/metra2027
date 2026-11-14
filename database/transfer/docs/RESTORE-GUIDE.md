# Restore guide — experimental source to a new target

## Scope

The current scripts restore the application's public/private schemas and data. They do not restore Supabase-managed Auth, Storage objects, project settings, extensions, API secrets, or provider configuration. The scripts recreate the reviewed application role ACLs, sequence/function grants, and public default privileges. Schema import refuses to proceed unless the target has every required extension at the recorded version and schema. No rows from `metra_observation_records` are transferred; this includes both demo and non-demo rows. The manifest explicitly records that all observation rows are excluded, and target acceptance requires that table to remain empty. This is a database transfer pack, not a complete Supabase project clone.

## Required inputs

An export directory from 01_export_source.sh containing:
- 01_schema_application.sql.gpg
- 02_data_application.sql.gpg
- 03_inventory_tables.txt
- 03_inventory_functions.txt
- 04_auth_user_fk_inventory.txt
- 05_observation_provenance.txt
- 06_runtime_role_inventory.txt
- 07_extensions.txt
- 08_station_catalogue_provenance.txt
- SHA256SUMS
- MANIFEST.txt

Also required: a new, explicitly identified Supabase target with an empty application public/private schemas, the transfer passphrase from a protected secret manager, PostgreSQL client tools, and GPG.

## Restore sequence

Set `METRA_DST_PROJECT_REF` and `METRA_DST_DATABASE_URL` to the new target. Supply `METRA_TRANSFER_PASSPHRASE` through a protected secret manager. Never paste credentials or passphrases into chat or Git.

1. Run `scripts/02_install_required_extensions.sh` with the export directory. It verifies the manifest/checksums, installs only the recorded source extensions into their recorded schemas, and verifies exact versions.
2. Run `scripts/02_bootstrap_target.sh` to create the least-privilege non-login runtime role, private schema, and public default ACLs.
3. Run `scripts/03_import_schema.sh` with the export directory. It verifies the complete manifest, required extensions, target identity and emptiness, then imports in one transaction.
4. Run `scripts/06_apply_runtime_grants.sh` after schema import.
4. Confirm the export manifest states `auth_user_count=0`, `all_observation_records_excluded=true`, `demo_observation_records_excluded=true`, and `non_demo_observation_records_excluded=true`. The source exporter refuses any snapshot with Auth users; do not bypass this guard or copy managed `auth.*` tables.
5. Review `04_auth_user_fk_inventory.txt`. Since the accepted source Auth count is zero, declared FK columns must not contain non-null source-user references. The comparison step separately checks their row, non-null, and distinct counts.
6. Run `scripts/04_import_data.sh` with the export directory. It verifies checksums and manifest, confirms the zero-user Auth boundary, checks required extensions and target emptiness, rejects excluded observation-history data, then imports in one transaction.
7. Set `METRA_SRC_PROJECT_REF` to `tbdnklyxjvbrilvnwgmq` and `METRA_SRC_DATABASE_URL` to the approved source URL. Run `scripts/05_compare.sh`.
8. Review `05_observation_provenance.txt` and `08_station_catalogue_provenance.txt`. Reconcile source-system/source-table groups, records without `station_id`, coordinate gaps, orphan coordinates, and duplicate station-coordinate links before accepting the restored dataset.
9. Audit unconstrained UUID references and IDs embedded in JSON/text separately; the standalone remapper is not invoked by this transfer path.

## Acceptance tests

- [ ] SHA-256 verification succeeds for all export artifacts.
- [ ] Public/private schema and data import complete without errors.
- [ ] Exact public/private row counts, non-Auth-FK SHA-256 table-content fingerprints, Auth FK row/null/distinct counts, sequence state, object inventory, and role/default-ACL comparison pass; required source extensions and station catalogue provenance are present on target.
- [ ] Foreign keys validate; Auth FK non-null counts remain zero and no orphaned user references remain.
- [ ] RLS policies and required grants are verified separately with anonymous, authenticated, and privileged test identities.
- [ ] No demo or live observation rows are imported; any later synthetic demo observations use a separate reviewed seed fixture.
- [ ] .NET health/readiness, login, station directory, observation gating, and Flutter login smoke tests pass.
- [ ] A separate full restore drill succeeds from the retained encrypted archive.

## Rollback and source retention

Keep the experimental project tbdnklyxjvbrilvnwgmq unchanged and available until a complete restore drill, comparison report, application tests, and owner sign-off are complete. This pack does not issue destructive commands against the source.
