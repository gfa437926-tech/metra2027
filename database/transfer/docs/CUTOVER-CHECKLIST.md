# Cutover checklist — experimental tbdnklyxjvbrilvnwgmq → new project

## Before any target write

- [ ] Source ref confirmed: tbdnklyxjvbrilvnwgmq
- [ ] Target ref assigned by owner; distinct from source and all legacy projects
- [ ] Source export completed in a secure runtime
- [ ] GPG encryption and SHA-256 manifest verified
- [ ] Encrypted backup retained offline/outside Git
- [ ] Restore drill performed into an isolated target
- [ ] Export manifest confirms `auth_user_count=0`; any non-zero source Auth count blocks export
- [ ] Auth FK inventory reviewed; non-null source-user references must be zero; no blind UUID rewriting
- [ ] Observation provenance reviewed; all demo and non-demo observation records excluded; 1,251 historical rows without `station_id` documented
- [ ] Legacy METRA databases not used

## Target project bootstrap

- [ ] New Supabase project created under the intended organization/account
- [ ] Auth site URL, redirect URLs, SMTP, and providers configured independently
- [ ] Required extensions installed at source-compatible versions and schemas
- [ ] `metra_observation_records` target table is empty; neither demo nor non-demo source rows were transferred
- [ ] New station catalogue content matches; coordinate gaps reported by the source provenance inventory are reviewed and no orphan/duplicate coordinate links exist
- [ ] New target publishable/anon and server-only secret/service_role keys generated
- [ ] Backend secrets configured only in target secret store
- [ ] Flutter configuration uses target URL and public publishable key only

## Data / schema

- [ ] Target runtime role and private schema bootstrapped with least privilege
- [ ] Public/private schema import completed atomically
- [ ] Reviewed object grants match the acceptance inventory
- [ ] Target default ACLs are restrictive: no implicit PUBLIC/anon/authenticated privileges on future tables, sequences, or functions; service_role only
- [ ] Private default functions are executable only by metra_api_runtime; audit trigger functions have `search_path=pg_catalog`
- [ ] SHA-256 checks pass before each import
- [ ] No source Auth users, identities, sessions, or credentials are copied
- [ ] Auth FK row/non-null/distinct counts match between source and target
- [ ] Sequence definitions and current values match after pg_dump setval restoration
- [ ] Unconstrained UUID/JSON references separately audited and reconciled
- [ ] Public/private data import completed atomically after manifest and empty-target guards
- [ ] Exact public/private row-count, object inventory, object-grant acceptance comparison, and restrictive default-ACL assertions pass
- [ ] Foreign keys validate; no orphaned user references remain
- [ ] RLS policies and grants verified separately
- [ ] Critical RPCs present and their signatures/authorization verified

## Application verification

- [ ] /api/v1/health OK on staging API
- [ ] /api/v1/ready behavior understood (may 503 until approved atomic RPCs exist)
- [ ] Login and station directory work for target test users
- [ ] Archive remains fail-closed until RPCs and grants exist
- [ ] Observation submit stays gated until scientific/atomic contract is approved
- [ ] Flutter and .NET use target project settings only

## Source project retention

- [ ] Source remains unchanged
- [ ] Encrypted source backup independently verified restorable
- [ ] Owner explicit approval required before any source teardown
