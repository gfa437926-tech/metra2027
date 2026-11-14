# METRA 2027 — Stage C Report (Isolated PostgreSQL + Migration Review)

**Branch:** `work/backend-db-integration-phase`  
**Date:** 2026-11-11  
**Isolated engine:** PostgreSQL 16.15 (local cluster `16/main`, database `metra_isolated` / `metra_mig_test`)  
**Hosted Supabase:** not touched  
**Legacy DB:** not touched  

## 1. Migration inventory

### `database/migrations/` (sorted)
003–022, 023_bind_authority…, **030** archive proposal (renamed from conflicting 023), 024–029.

**Conflict found:** two files previously shared prefix `023_`. Resolved by renaming archive proposal → `030_observation_archive_read_permission_proposal.sql`.

### `supabase/migrations/`
5 operational observation files (submission, deny client access, indexes, review decision, null hardening).

### Existing CI DB “tests”
`database/tests/verify_*.sh` are **static grep contracts** on SQL source text — they passed (11/12 scripts; one may have been truncated in log). They are **not** live PostgreSQL execution.

## 2. Apply-from-empty results (actual `psql`)

Fresh database `metra_mig_test` owned by `metra_test`.

| File | Result | Primary error |
|------|--------|----------------|
| 003_station_permission_rpc | FAIL | `metra_account_states` does not exist |
| 004–005, 007, 011… permission inserts | FAIL | `metra_role_permissions` does not exist |
| 006 registration decision | FAIL | role `anon` does not exist (Supabase roles assumed) |
| 008–029 (most) | FAIL | missing base relations and/or Supabase roles |
| 023 proposal (now 030) | OK | pure `SELECT` marker only |

**Conclusion:** `database/migrations/` are **incremental** on an assumed base schema (catalogue, accounts, grants, `auth.users`, roles `anon`/`authenticated`/`service_role`). They cannot be applied alone from a blank PostgreSQL without a baseline schema pack that is **not present** as ordered CREATE TABLE migrations in this folder.

This is a repository gap, not a hosted change.

## 3. Live archive isolation tests (actual PostgreSQL)

Assets under `database/isolated/`:
- `00_bootstrap_minimal_schema.sql` — minimal tables + station-scoped archive predicate requiring **grant.station_id = requested station**
- `01_seed_archive_isolation_fixtures.sql` — **two stations, same authority**
- `02_test_archive_isolation.sql` — assertions

### Evidence (NOTICE lines from live run)

```
PASS: observer archive A allowed
PASS: observer archive B denied (same authority)
PASS: role-only archive denied
PASS: revoked grant denies archive A
PASS: expired assignment denies archive
PASS: audit update blocked
PASS: audit delete blocked
ALL ARCHIVE ISOLATION TESTS PASSED
```

Scenarios proven on engine:
1. Explicit ArchiveRead on A → allow A  
2. Same user, same authority, station B → deny  
3. station_head with review/approve roles, no archive grant → deny  
4. After revoke → deny  
5. Expired station assignment → deny  
6. permission_grant_audit UPDATE/DELETE → blocked (append-only)

## 4. Data design review (modules vs presence)

| Module | Present in migrations/supabase | Gap |
|--------|--------------------------------|-----|
| Users / accounts / roles | role catalogue seed; account states referenced | base CREATE not in numbered migrations |
| Authorities / memberships / grants | 015–029 lifecycle | solid incremental; needs base |
| Stations / assignments / station audit | 003–014 | solid incremental |
| Hourly/Daily observations | supabase operational observation tables | validators in .NET; schema partial |
| Review / approval | observation decision migrations | present |
| Electronic audit (full met record) | observation audit events append-only | not full independent electronic-audit warehouse |
| Observation archive read-model | **missing production table/RPC** | isolated design only; API remains 503 |
| Forecast / AI / Climatol / notifications | not found as first-class tables | deferred; no fake engines |

## 5. Archive read-model proposal (not hosted)

- Reuse approved observations / imported historical rows only after contract approval.
- Predicate: `metra_user_has_station_permission(user, station, 'observation.archive.read')` with **station_id bound on grant**.
- Endpoint stays fail-closed until isolated tests + your explicit apply approval.

## 6. Changes requiring your approval later

1. Adding a true baseline schema migration pack (CREATE TABLE for catalogue/accounts/grants/…) so empty-DB replay works.
2. Any apply of 030+ archive DDL/RPC to hosted Supabase.
3. Creating production archive read-model tables.

## 7. CI / static contracts

- Ran all `database/tests/verify_*.sh` in this environment: contracts verified (source-level).
- Backend .NET tests not re-run here (no SDK).
- Flutter CI not executed (no Flutter SDK).

## 8. Stage C status

| Requirement | Status |
|-------------|--------|
| Review migrations | Done |
| Isolated PostgreSQL | Done (PG 16.15) |
| Apply all migrations from empty | Attempted; **documented failures** due to missing baseline |
| Archive isolation SQL tests live | **Passed** |
| No hosted writes | Respected |
| Report with evidence | This document |

**Stage C complete for isolation evidence and gap documentation.**  
Stage D can formalize security matrix; Stage E remains blocked until real services pass tests.
