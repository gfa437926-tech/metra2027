# METRA 2027 — Reporting and Archive Read-Only Schema Review

- Inspection date: 2026-11-11
- Target: Supabase project `metra2027-angular` (`tbdnklyxjvbrilvnwgmq`, `eu-west-2`)
- Database: PostgreSQL 17.11
- Method: Supabase table metadata, migration inventory, RLS policies, grants, function catalogue, aggregate-only data-quality counts and security/performance advisors.
- Scope: read-only inspection only. No INSERT, UPDATE, DELETE, DDL, migration, RPC deployment, policy/grant change or secret access was performed.
- Legacy project `INSERT` (`vktcvkwqszehgmhqjrkb`) was not queried or modified.

## 1. Verified observation stores

Two separate tables exist and must not be conflated.

### 1.1 Imported historical archive — `public.metra_observation_records`

- RLS enabled.
- 58,059 rows.
- Primary key: `id uuid`.
- Columns:
  - `source_system text NOT NULL`
  - `source_table text NOT NULL`
  - `source_record_id text NOT NULL`
  - `station_id uuid NULL`
  - `station_name_source text NULL`
  - `observation_type text NOT NULL`
  - `observed_at timestamptz NULL`
  - `payload jsonb NOT NULL`
  - `is_demo boolean NOT NULL`
  - `imported_at timestamptz NOT NULL`
- Foreign key: `station_id → station_catalogue.id`.
- RLS policy observed: `metra_observation_records_deny_all` for `anon, authenticated` (USING false / WITH CHECK false).
- `service_role` has broad table privileges. The dedicated `metra_api_runtime` role has no table grant and no runtime SELECT policy on this table at inspection time.
- The archive contains imported records, not an operational review workflow. It has no status, submitter, review actor, decision, or version columns.

Aggregate-only quality counts read from the table:

| observation_type | total | unlinked station | missing observed_at | demo |
|---|---:|---:|---:|---:|
| agricultural | 176 | 0 | 0 | 0 |
| climate | 1,420 | 2 | 1 | 0 |
| daily | 3,760 | 103 | 2 | 0 |
| fieldclimate | 19,764 | 0 | 0 | 0 |
| hourly | 32,084 | 1,146 | 10 | 0 |
| phenomenon | 54 | 0 | 0 | 0 |
| soil | 801 | 0 | 0 | 0 |
| **Total** | **58,059** | **1,251** | **13** | **0** |

Station-scoped archive queries must exclude rows with `station_id IS NULL`; they must not guess station links from `station_name_source`. Unlinked reconciliation belongs in a separately authorized data-quality workflow, not the station archive.

### 1.2 Operational submissions — `public.metra_observations`

- RLS enabled and forced.
- 0 rows at inspection time.
- Columns: `id`, `station_id`, `created_by`, `observation_type`, `observed_at`, `payload`, `status`, `initial_status`, `idempotency_key`, `submitted_at`, `reviewed_by`, `reviewed_at`, `review_note`, `created_at`, `updated_at`.
- Current observation type constraint: `daily`, `hourly`, `phenomenon`.
- Current status constraint: `draft`, `submitted`, `returned`, `approved`.
- The table is explicitly separate from imported archive envelopes.
- RLS policy observed: `metra_observations_deny_client_access` for `anon, authenticated`.
- The migration revokes all direct privileges from `metra_api_runtime`; only `service_role` has SELECT/INSERT in the observed operational submission migration.
- Therefore the current dedicated runtime role cannot read this table. Do not bypass this by putting the service-role key in Flutter or Angular.

### 1.3 Operational audit events — `public.metra_observation_audit_events`

- RLS enabled and forced.
- 0 rows at inspection time.
- Columns: `id bigint`, `observation_id uuid`, `station_id uuid`, `actor_user_id uuid`, `event_type text`, `from_status text NULL`, `to_status text`, `note text NULL`, `occurred_at timestamptz`.
- Foreign keys to operational observation, station and Auth user.
- Client-deny RLS policy exists.
- Runtime role has no SELECT grant/policy at inspection time.
- The audit table records workflow events, not historical payload snapshots. It is not a complete immutable observation-version store.

## 2. Verified authorization substrate

The following tables exist, have RLS enabled, and have read access for the dedicated runtime role:

- `metra_account_states` — account lifecycle state.
- `station_assignments` — station/user assignment and validity.
- `permission_grants` — explicit permission codes, approval and validity/revocation.
- `station_catalogue` — canonical operational station identity.

The schema has time-bounded station assignments and permission grants, including `valid_from`, `valid_to`, and (for permission grants) `revoked_at`. The API must check active account, exact station assignment and an explicit approved permission at read time.

The archive permission code itself was not approved or identified as an existing grant in this review. Do not silently reuse review/approve permission codes as archive-read permission.

## 3. Security and performance advisor observations

The security advisor returned:
- RLS-enabled tables without policies for equipment-fault/support-incident tables (outside this reporting/archive scope).
- Mutable search-path warnings for two equipment/support audit trigger functions (outside this reporting/archive scope).
- The two observation tables and imported archive have client-deny policies, but no dedicated runtime SELECT policy was observed.

The performance advisor returned informational notices for unindexed foreign keys and unused indexes. No index is to be dropped based solely on an unused-index notice. A separate query-plan review should be done after the archive read query is implemented in an isolated environment.

## 4. Safe architecture recommendation

Use the existing `metra_api_runtime` principal for read-only archive/report queries rather than the broad `service_role` credential.

A future migration proposal should:
1. Grant SELECT only on the exact observation/archive/audit relations required.
2. Add RLS policies for `metra_api_runtime` SELECT only; keep `anon` and `authenticated` denied.
3. Preserve append-only audit constraints and grant no UPDATE/DELETE/INSERT to the archive reader.
4. Use one parameterized PostgreSQL statement (or a reviewed RPC) that checks the JWT-derived actor's active account, approved explicit archive-read permission and exact active station assignment while selecting rows for that same station. This makes authorization and data selection share one database statement snapshot.
5. Filter archive rows by exact `station_id`; never infer links for the 1,251 unlinked rows.
6. Keep imported archive payloads read-only. No legacy source re-import or data mutation is part of this API work.

For operational observations, keep the existing submission/decision RPCs unchanged. Add only read-only runtime access after a dedicated schema/permission review. The current B-013 queue authorization/read gap remains a separate finding until its queue implementation is changed and race-tested.

## 5. Reporting implications

- The historical archive can initially expose source-preserving imported envelopes by observation type and UTC timestamp, with explicit handling for null timestamps and unlinked station records.
- It must label imported records as imported/archive data, not newly submitted or reviewed METRA observations.
- The operational table currently has zero rows, so no current operational report data can be shown as populated.
- The operational audit table contains no payload versions. A history screen may show event metadata only after runtime read access and authorization are approved; it must not claim that prior payload versions can be restored.
- Hourly/daily aggregates, daily period boundaries, monthly/annual statistics, units, completeness thresholds, rainfall/snow/agriculture/soil rules, Climatol outputs and exports require separate domain contracts. The table metadata alone does not authorize scientific calculations.

## 6. Decision gates

| Gate | Finding | Required action |
|---|---|---|
| Archive storage | Verified: 58,059 imported envelopes | Approve station-scoped read contract |
| Runtime read access | Missing for archive and operational observation tables | Review and approve least-privilege grant/RLS migration |
| Archive permission | No explicit archive-read grant confirmed | Approve permission catalogue entry and assignment scope |
| Station isolation | Can be checked using active account, station assignment and explicit permission | Implement as one SQL statement/transaction and add DB integration tests |
| Unlinked records | 1,251 have NULL station_id | Keep out of station-scoped archive; reconcile separately |
| Version history | Audit events contain state transitions, not payload snapshots | Separate versioning proposal required |
| Scientific reports | Calculation/units/completeness rules unresolved | Meteorological owner approval required |
| Operational reports | Operational table had 0 rows at inspection | UI must show empty state, not demo numbers |

## 7. Explicit non-actions

- No SQL writes or DDL.
- No migration applied.
- No RPC, RLS policy or grant changed.
- No source records or station links modified.
- No service-role secret retrieved or exposed.
- No INSERT/legacy project access.
- No METRA OLD repository/database access.
