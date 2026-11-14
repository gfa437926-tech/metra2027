# Cutover checklist — experimental tbdnklyxjvbrilvnwgmq → new project

## Before any target write

- [ ] Source ref confirmed: tbdnklyxjvbrilvnwgmq
- [ ] Target ref assigned by owner; distinct from source and all legacy projects
- [ ] Source export completed in a secure runtime
- [ ] GPG encryption and SHA-256 manifest verified
- [ ] Encrypted backup retained offline/outside Git
- [ ] Restore drill performed into an isolated target
- [ ] Auth FK inventory reviewed; no blind UUID rewriting
- [ ] Observation provenance summary reviewed; non-demo records and null station references reconciled
- [ ] Legacy METRA databases not used

## Target project bootstrap

- [ ] New Supabase project created under the intended organization/account
- [ ] Auth site URL, redirect URLs, SMTP, and providers configured independently
- [ ] Required extensions installed at source-compatible versions and schemas
- [ ] `metra_observation_records` target table is empty; non-demo source rows were not transferred
- [ ] New station catalogue content matches; coordinate gaps (15 in source) are reviewed and no orphan/duplicate coordinate links exist
- [ ] New target publishable/anon and server-only secret/service_role keys generated
- [ ] Backend secrets configured only in target secret store
- [ ] Flutter configuration uses target URL and public publishable key only

## Data / schema

- [ ] Target runtime role and private schema bootstrapped with least privilege
- [ ] Public/private schema import completed atomically
- [ ] Managed role, PUBLIC, sequence, function, and metra_api_runtime ACLs match the source inventory
- [ ] SHA-256 checks pass before each import
- [ ] Auth users recreated/invited through supported target Auth flow
- [ ] Protected source→target UUID mapping reviewed and stored outside Git with mode 0600
- [ ] Every mapped target UUID exists in target auth.users
- [ ] Declared Auth FK columns remapped by the tested COPY transformer
- [ ] Unconstrained UUID/JSON references separately audited and reconciled
- [ ] Public/private data import completed atomically after Auth UUID remapping
- [ ] Exact public/private row-count, object, and ACL inventory comparison passes
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
