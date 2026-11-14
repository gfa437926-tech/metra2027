# METRA 2027 — Experimental → Target Supabase Transfer Pack

**Source project (experimental only):** `tbdnklyxjvbrilvnwgmq`
**Target project:** to be named by the owner later.
**Forbidden:** any legacy METRA database outside the experimental project.
**Baseline:** `3fdc0593d08991d9e540d20fe973c790f7cd5b64`

## Purpose and safety boundary

Repeatable export/import of the approved experimental project's `public` and `private` schemas and data to a future, explicitly identified target.
The source is never modified or deleted by this pack. It does not copy API keys, JWT secrets, Auth sessions, refresh tokens, or managed Supabase schemas.
The export writes AES-256 encrypted GPG dumps, SHA-256 checksums, an inventory of declared application foreign keys referencing auth.users, a row-count summary grouped by observation source table/system/demo flag, and an ACL/default-privilege inventory. The passphrase must be supplied through a protected shell environment and stored separately from artifacts.

## Scripts

- `scripts/lib/project_url_guard.sh` — checks that a Postgres URL identifies the exact project ref
- `scripts/00_preflight.sh` — read-only source identity/connectivity check
- `scripts/01_export_source.sh` — encrypted public/private schema/data export, strips pre-existing schema creation statements, SHA-256 manifest, JSON-lines Auth-user FK inventory, observation provenance, station catalogue provenance, and role ACL inventory
- `scripts/02_install_required_extensions.sh` — installs the recorded source extensions and verifies exact target versions/schemas
- `scripts/02_bootstrap_target.sh` — creates the runtime role and restrictive target default ACLs
- `scripts/03_import_schema.sh` — verifies the complete manifest, then atomically decrypts/imports public/private schemas into an empty target
- `scripts/04_import_data.sh` — verifies the complete manifest and zero-source-Auth-user boundary, checks target emptiness, rejects all observation data, then atomically imports public/private data into empty tables
- `scripts/06_apply_runtime_grants.sh` — reapplies reviewed object grants and verifies restrictive target default ACLs
- `scripts/remap_auth_user_ids.py` — standalone, unit-tested future utility; deliberately not called by the current import path because source Auth users must be zero
- `scripts/05_compare.sh` — exact public/private row counts, SHA-256 data/object fingerprints, Auth FK counts, sequence state, reviewed object-grant comparison, and restrictive target default-ACL assertion
- `sql/bootstrap_target_roles.sql` and `sql/apply_runtime_grants.sql` — target role, default ACL, and explicit grant restoration
- `sql/compare_acl_inventory.sql` — full source ACL inventory, including the source's broad public default ACLs, retained for audit
- `sql/compare_acl_inventory_acceptance.sql` — compares reviewed object grants while excluding intentionally tightened source defaults and client sequence/trigger-function grants
- `tests/assert_target_default_acl.sql` — requires no implicit PUBLIC/anon/authenticated privileges on future public objects
- `tests/assert_target_function_search_path.sql` — verifies audit trigger functions use `search_path=pg_catalog`
- `sql/compare_auth_fk_counts.sql` — compares Auth FK row/null/distinct counts while allowing regenerated target UUID values
- `sql/compare_sequence_state.sql` — compares sequence configuration and restored `last_value` values
- `sql/compare_data_hashes.sql` — hashes all non-Auth-FK application columns so regenerated Auth IDs do not create false data drift
- `sql/compare_extensions.sql` — source extension/version/schema inventory; target restore requires each source extension
- `sql/station_catalogue_provenance.sql` — checks station catalogue, coordinate coverage, orphan rows, and duplicates
- `sql/compare_excluded_data.sql` — verifies the target has no observation-history rows excluded by policy
- `sql/assert_empty_application_tables.sql` — read-only guard that blocks data import into populated tables
- `tests/create_managed_roles.sql` and `tests/runtime_role_fixtures.sql` — isolated PostgreSQL fixtures for ACL tests
- `tests/test_url_guard.sh` — direct-host, trusted-pooler, spoofed-pooler, wrong-project URL, and pg_dump compatibility tests
- `tests/test_auth_user_remap.py` — mapping privacy, duplicate IDs, exact FK-only replacement, and fail-closed COPY parsing tests
- `tests/test_install_extensions.sh` — idempotent extension install and exact version/schema verification
- `tests/test_import_data.sh` — end-to-end import, manifest, empty-target, and excluded-observation guards
- `tests/test_compare_contract.sh` — static contract guard ensuring every declared source/target comparison and target-only acceptance check remains wired into `05_compare.sh`
- `tests/test_empty_target_guard.sh` — disposable-PostgreSQL regression proving the empty-target guard accepts an empty application schema and rejects a populated one
- `tests/test_excluded_observation_guard.sh` — disposable-PostgreSQL regression proving the excluded observation-history acceptance query reports zero for an empty target and detects a populated target
- `tests/test_checksums.sh` — exact artifact-set, tamper, duplicate, and path-traversal checksum-manifest tests
- `tests/test_public_schema_normalizer.sh` — ensures the export omits the existing public schema creation statement and rejects unexpected dump structure
- Export artifacts also include `04_auth_user_fk_inventory.txt` (JSON Lines), `05_observation_provenance.txt`, `06_runtime_role_inventory.txt`, `07_extensions.txt`, and `08_station_catalogue_provenance.txt`; review Auth references, observation provenance, station/coordinate integrity, and ACL inventory before accepting a restore.

There is no `02_inventory_source.sh`; inventory output is generated by `01_export_source.sh`.

## Secure environment

Never paste credentials or passphrases into chat or Git. Set them in a protected local shell/secret manager:

```bash
export METRA_SRC_PROJECT_REF=tbdnklyxjvbrilvnwgmq
export METRA_SRC_DATABASE_URL='postgresql://...'
export METRA_TRANSFER_PASSPHRASE='use-a-long-random-secret-from-your-secret-manager'
export METRA_DST_PROJECT_REF='<new-ref>'
export METRA_DST_DATABASE_URL='postgresql://...'
```

The export checks that pg_dump's major version is at least the connected PostgreSQL server's major version (the approved source currently runs PostgreSQL 17). The URL guard accepts direct `db.<ref>.supabase.co` hosts or Supavisor usernames `postgres.<ref>` only when paired with a `*.pooler.supabase.com` host. If the URL cannot prove the expected ref, the script refuses to proceed.

## Comparison scope

- Row counts use exact `COUNT(*)` for each public/private table except the intentionally excluded `public.metra_observation_records`; that target table is separately required to be empty. This can be expensive on large datasets.
- Object comparison fingerprints table columns, indexes, views, functions/procedures, types, constraints, triggers, RLS flags, and policy expressions in public/private. It is a structural fingerprint, not a byte-for-byte database file comparison.
- Managed Auth, Storage objects, extensions, secrets, provider settings, and user identities are outside this automated transfer scope. The full source ACL inventory is retained for review. The target intentionally tightens default privileges: only server-side `service_role` receives implicit public table/sequence/function privileges; private functions are implicitly executable only by `metra_api_runtime`; `PUBLIC`, `anon`, and `authenticated` receive none. Audit trigger functions are pinned to `search_path=pg_catalog`. Existing object grants are checked against a separate acceptance inventory.

## Automated validation

`.github/workflows/transfer-pack.yml` runs isolated PostgreSQL SQL checks and GPG integrity checks. `.github/workflows/transfer-auth-remap.yml` runs ShellCheck, Python remapper tests, PostgreSQL ACL/sequence/station SQL checks, extension installation, and end-to-end data-import tests. These checks do not connect to Supabase and do not prove a live export/import.

## Auth and restore status

Auth users are not exported or imported. The exporter refuses to proceed if `auth.users` is non-empty, and the manifest requires `auth_user_count=0`. The remapping utility is standalone and is not part of the current import path. Auth FK cardinality is compared separately; unconstrained UUID/JSON references still require a separate audit. Never copy active sessions or source JWT secrets.
A successful script run is not a restore acceptance. A full restore drill, application smoke tests, row/object comparison, and owner sign-off remain required.

## Live dump status

No hosted export, target import, restore drill, or live cutover is claimed by this repository change. All observation history (demo and non-demo) is intentionally excluded. The scripts require secure runtime credentials and an explicitly named new target.
