# METRA 2027 — Schema reconciliation matrix

**Branch:** `work/metra-full-schema-recovery-2026-11-14`  
**Status:** static source reconciliation; no DDL replay or hosted database access.  
**Source scope:** current branch Baseline 001–008, `database/migrations/003–029`, role seed, and the migration source references documented in the extraction report.

## Decision rule

A column is considered canonical only when its authoritative definition is present in the reviewed schema pack or an explicitly approved schema specification. A function reference, UI model, or test fixture proves a dependency, not the intended type, nullability, default, or constraint. Therefore this matrix records required compatibility but does not silently invent DDL.

## Verified reconciliation items

| Relation | Baseline definition | Migration dependency / conflict | Status |
|---|---|---|---|
| `metra_user_profiles` | `user_id, display_name, phone, created_at, updated_at` (002/006) | 008 reads `first_name, father_name, last_name` | **Blocked:** canonical profile fields and nullability not established |
| `station_catalogue` | 003 defines `station_code`, names, coordinates and status fields | 008 reads `local_station_code` | **Blocked:** decide whether `local_station_code` replaces or supplements `station_code`; do not alias by guess |
| `metra_account_states` | 005 defines `user_id, account_state, updated_at` | 009 reads `state_reason` | **Blocked:** missing column contract |
| `registration_requests` | 006 skeleton: `id, user_id, requested_station_id, requested_role_code, status, created_at, updated_at` | 008/009 require `phone_snapshot, terms_version, submitted_at, review_note`; submission workflow also uses idempotency and status semantics | **Blocked:** full request lifecycle contract required |
| `registration_audit_events` | 006 defines `actor_user_id, action_code, from_status, to_status, note, occurred_at` | 008 reads `user_id, event_type, terms_version, decision_note` | **Blocked:** shape mismatch; migration/read-model contract must be reconciled |
| `station_assignments` | 005 has core identity, station, authority, role, approval and validity fields | 012 workflow writes/updates `requested_by, reason, approved_by, reviewed_at, updated_at` | **Blocked:** workflow columns absent from baseline |
| `station_audit_log` | 006 uses `station_id, actor_user_id, event_type, payload, occurred_at` | 012/014 use entity/action audit shape: `entity_type, entity_id, action, actor_id, reason, before_data, after_data, occurred_at` | **Blocked:** incompatible audit model; choose a single reviewed contract and preserve audit semantics |
| `authority_memberships` | 005 defines membership identity, authority, role, approval and validity | 020+ lifecycle/read models use `requested_by, reason` and lifecycle fields | **Blocked:** full lifecycle contract required |
| `permission_grants` | 005 already defines `authority_id`, `station_id`, status, validity, revocation and reviewer fields | 020/021 lifecycle expects `requested_by, reason`; 020 also attempts to add `authority_id` already present in Baseline | **Blocked:** duplicate-column hazard plus missing lifecycle contract |
| `authority_access_audit_events` | 007 creates the append-only audit relation | 020 also contains table-creation DDL for the same relation | **Blocked:** duplicate object creation path; exact guard and column compatibility must be checked before replay |
| `metra_role_catalogue` / `metra_role_permissions` | 004 creates catalogues; seed adds eight role records | RPC/workflow migrations depend on permission mappings beyond role rows | **Partial:** seed role rows are not a complete permission allow-list; authoritative mappings must be derived and reviewed |

## Important source-of-truth findings

1. `database/baseline/README.md` explicitly labels the pack as a **generic PostgreSQL isolated baseline**, not a hosted Supabase apply script. It documents the observation tables as deferred to `supabase/migrations`.
2. `database/README.md` separately identifies the new Supabase project and explicitly prohibits writes to the legacy project. This does not authorize a hosted apply.
3. `docs/delivery/BASELINE-SCHEMA-GAP-AND-PROPOSAL.md` records that the initial baseline pack required explicit approval and that migration replay was not proven. It is a proposal/history document, not a source for guessing column definitions.
4. `database/isolated/00_bootstrap_minimal_schema.sql` is a focused test fixture. It must not be promoted into the canonical full schema.
5. `database/seeds/001_role_catalogue.sql` supplies role descriptions and requestability; it does not by itself define the complete permission matrix.

## Safe next actions

- Recover the approved full relation definitions (including column types, nullability, defaults, keys, checks, indexes and trigger contracts) from the authoritative schema package or an explicitly approved schema export.
- Reconcile the migration chain against those definitions, preserving migration history. Do not paper over incompatibilities with blanket `IF NOT EXISTS`.
- Add a preflight gate that fails on unresolved relation/column dependencies before any isolated replay.
- Only after static reconciliation is clean, build two disposable PostgreSQL databases and run the replay and catalog comparison.

## Completion gate

**Not complete:** no canonical full-schema source has yet been identified for every blocked relation; no disposable PostgreSQL replay has been run; no schema-equivalence result exists. No hosted Supabase project, legacy database, or `main` branch was modified.
