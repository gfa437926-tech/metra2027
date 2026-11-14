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
- [ ] New target publishable/anon and server-only secret/service_role keys generated
- [ ] Backend secrets configured only in target secret store
- [ ] Flutter configuration uses target URL and public publishable key only

## Data / schema

- [ ] Public schema import completed atomically
- [ ] Public data import completed atomically
- [ ] SHA-256 checks pass before each import
- [ ] Auth users recreated/invited through supported target Auth flow
- [ ] User UUID mapping applied only to verified FK columns
- [ ] Exact public row-count and object inventory comparison passes
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
