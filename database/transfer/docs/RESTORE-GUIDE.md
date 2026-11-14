# Restore guide — experimental source to a new target

## Scope

The current scripts restore the application's public/private schemas and data. They do not restore Supabase-managed Auth, Storage objects, project settings, extensions, API secrets, or provider configuration. The scripts recreate the reviewed application role ACLs, sequence/function grants, and public default privileges. Schema import refuses to proceed unless the target has every required extension at the recorded version and schema. No rows from `metra_observation_records` are transferred; target acceptance requires that table to remain empty. This is a database transfer pack, not a complete Supabase project clone.

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
- SHA256SUMS
- MANIFEST.txt

Also required: a new, explicitly identified Supabase target with an empty application public/private schemas, the transfer passphrase from a protected secret manager, PostgreSQL client tools, and GPG.

## Restore sequence

Set `METRA_DST_PROJECT_REF` and `METRA_DST_DATABASE_URL` to the new target. Supply `METRA_TRANSFER_PASSPHRASE` through a protected secret manager. Never paste credentials or passphrases into chat or Git.

1. Run `scripts/02_bootstrap_target.sh` to create the least-privilege non-login runtime role, private schema, and public default ACLs.
2. Run `scripts/03_import_schema.sh` with the export directory. It verifies the complete manifest, required extensions, target identity and emptiness, then imports in one transaction.
3. Run `scripts/06_apply_runtime_grants.sh` after schema import.
4. Review `04_auth_user_fk_inventory.txt`. Recreate target Auth users through the supported target Auth flow and prepare a protected `source_user_id,target_user_id` CSV mapping. Set its file mode to `0600`.
5. Set `METRA_AUTH_USER_MAPPING_FILE` to the protected mapping file. The data importer checks that all mapped target UUIDs exist in `auth.users`, then rewrites only the declared FK columns in the decrypted COPY dump. It fails closed on missing mappings or unexpected COPY structures.
6. Run `scripts/04_import_data.sh` with the export directory. It verifies checksums and manifest, checks required extensions and target emptiness, remaps declared Auth FK values, then imports in one transaction.
7. Set `METRA_SRC_PROJECT_REF` to `tbdnklyxjvbrilvnwgmq` and `METRA_SRC_DATABASE_URL` to the approved source URL. Run `scripts/05_compare.sh`.
8. Review `05_observation_provenance.txt`. Reconcile source-system/source-table groups and records without `station_id` before declaring the restored dataset accepted.
9. Audit unconstrained UUID references, JSON claims, and application metadata separately; the FK remapper does not rewrite these.

## Acceptance tests

- [ ] SHA-256 verification succeeds for all export artifacts.
- [ ] Public/private schema and data import complete without errors.
- [ ] Exact public/private row counts and SHA-256 table-content fingerprints, object inventory, and role/default-ACL comparison pass; required source extensions are present on target.
- [ ] Foreign keys validate and no orphaned user references remain after approved Auth remapping.
- [ ] RLS policies and required grants are verified separately with anonymous, authenticated, and privileged test identities.
- [ ] .NET health/readiness, login, station directory, observation gating, and Flutter login smoke tests pass.
- [ ] A separate full restore drill succeeds from the retained encrypted archive.

## Rollback and source retention

Keep the experimental project tbdnklyxjvbrilvnwgmq unchanged and available until a complete restore drill, comparison report, application tests, and owner sign-off are complete. This pack does not issue destructive commands against the source.
