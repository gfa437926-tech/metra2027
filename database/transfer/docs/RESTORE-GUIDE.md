# Restore guide — experimental source to a new target

## Scope

The current scripts restore only the application's public schema and data. They do not restore Supabase-managed Auth, Storage objects, project settings, extensions, grants, secrets, or provider configuration. This is a database transfer pack, not a complete Supabase project clone.

## Required inputs

An export directory from 01_export_source.sh containing:
- 01_schema_public.sql.gpg
- 02_data_public.sql.gpg
- 03_inventory_tables.txt
- 03_inventory_functions.txt
- 04_auth_user_fk_inventory.txt
- 05_observation_provenance.txt
- SHA256SUMS
- MANIFEST.txt

Also required: a new, explicitly identified Supabase target with an empty application public schema, the transfer passphrase from a protected secret manager, PostgreSQL client tools, and GPG.

## Restore sequence

Set METRA_DST_PROJECT_REF and METRA_DST_DATABASE_URL to the new target. Supply METRA_TRANSFER_PASSPHRASE through a protected secret manager. Never paste credentials or passphrases into chat or Git.

1. Run scripts/03_import_schema.sh with the export directory. It verifies the complete manifest, decrypts the schema, verifies target identity and emptiness, and imports in one transaction.
2. Run scripts/04_import_data.sh with the same export directory. It verifies the manifest again, refuses populated public tables, decrypts the data, and imports in one transaction.
3. Set METRA_SRC_PROJECT_REF to tbdnklyxjvbrilvnwgmq and METRA_SRC_DATABASE_URL to the approved source URL. Run scripts/05_compare.sh.
4. Review 04_auth_user_fk_inventory.txt and follow AUTH-USER-TRANSFER.md for target-side user recreation and carefully scoped UUID remapping.
5. Review 05_observation_provenance.txt. Reconcile source-system/source-table groups and records without station_id before declaring the restored dataset accepted.

## Acceptance tests

- [ ] SHA-256 verification succeeds for all export artifacts.
- [ ] Public schema and data import complete without errors.
- [ ] Exact public row counts and object inventory comparison passes.
- [ ] Foreign keys validate and no orphaned user references remain after approved Auth remapping.
- [ ] RLS policies and required grants are verified separately with anonymous, authenticated, and privileged test identities.
- [ ] .NET health/readiness, login, station directory, observation gating, and Flutter login smoke tests pass.
- [ ] A separate full restore drill succeeds from the retained encrypted archive.

## Rollback and source retention

Keep the experimental project tbdnklyxjvbrilvnwgmq unchanged and available until a complete restore drill, comparison report, application tests, and owner sign-off are complete. This pack does not issue destructive commands against the source.
