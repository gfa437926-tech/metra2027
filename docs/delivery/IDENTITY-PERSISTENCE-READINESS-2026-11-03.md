# METRA 2027 — Identity Persistence Readiness (2026-11-03)

## Verified target

- Supabase project: `metra2027-angular`
- Project ref: `tbdnklyxjvbrilvnwgmq`
- Region: `eu-west-2`
- PostgreSQL: 17.11
- Status at inspection: `ACTIVE_HEALTHY`
- Working repository branch: `work/identity-migration-audit`
- Repository: `gfa437926-tech/metra2027`

The legacy project `INSERT` (`vktcvkwqszehgmhqjrkb`) was not queried or modified during this inspection.

## Verified public-schema state

The target currently has 15 public tables, all with RLS enabled (latest row-count verification):

- `countries` (1 row)
- `meteorological_authorities` (1 row)
- `station_catalogue` (65 rows)
- `station_coordinates` (50 rows)
- `station_access_grants` (0 rows)
- `station_audit_log` (0 rows)
- `metra_account_states` (0 rows)
- `authority_memberships` (0 rows)
- `station_assignments` (0 rows)
- `permission_grants` (0 rows)
- `metra_user_profiles` (0 rows)
- `metra_observation_records` (58,059 rows)
- `metra_role_catalogue` (0 rows)
- `registration_requests` (0 rows)
- `registration_audit_events` (0 rows)

Applied migrations include the independent station catalogue, identity/membership/assignment tables, account profile/state, provenance-preserving observation store, registration workflow, least-privilege runtime role, and two-stage registration approval. The latest security advisor returned no findings. No indexes were removed.

## Persistence gap

The ASP.NET Core project has Npgsql connection-string configuration and domain/application contracts, but the inspected backend contains no production PostgreSQL implementation for:

- `ICurrentUserContextDataSource`
- `IMetraPermissionAuthorizationDataSource`
- `IMetraResourceAuthorizationDataSource`
- `IMetraActorAuthorizationContextDataSource`
- `IRegistrationSubmissionStore`
- The authoritative role/station registration catalogue and station-directory stores

The current public schema does not include a registration-request table or a dedicated METRA-to-Supabase-Auth identity-link table. The existing account state/profile tables are not a complete onboarding persistence workflow. The API therefore must remain fail-closed: do not register placeholder allow-all stores, remove 503 guards, or map registration routes before their real persistence dependencies exist.

## Next implementation sequence

1. Review the physical account/identity model against the existing domain contracts and the actual `auth.users(id)` lifecycle.
2. Add the required identity-link, registration-request, idempotency and append-only audit schema to the new target only, with explicit constraints, indexes, RLS and least-privilege runtime grants.
3. Implement Npgsql repositories using parameterized SQL and explicit transactions. Authorization-sensitive facts must be read from one consistent snapshot; registration must write the pending account/link/request/audit bundle atomically.
4. Implement authoritative role and station catalogue reads. Do not use display labels, request-supplied actor IDs, legacy station tables, or guessed station coordinates as authority.
5. Add isolated PostgreSQL integration tests for concurrency, idempotency, rollback, audit immutability, account suspension, membership and station-scope enforcement.
6. Register the real adapters and map protected endpoints only after the tests pass.
7. Run the .NET 10 CI workflow, then Angular/Flutter API integration and staging smoke tests. Keep production activation disabled until release gates pass.

## Safety invariants

- No query, update, delete, migration or other mutation is permitted against the legacy `INSERT` database. The user's prior constraint allows only INSERT operations there and permits migration from it into the new database.
- All schema and application changes in this workstream target `metra2027-angular` only.
- Never expose Supabase service-role/secret credentials to Angular or Flutter.
- Never trust JWT user metadata, request JSON, client storage, or client-provided role/station identifiers for authorization.
- Keep audit history append-only and write audit events in the same transaction as the business mutation they describe.
- Do not claim CI or integration tests passed unless a workflow/test result confirms it.


## Registration persistence increment — completed 2026-11-03

The following changes have now been applied to the new Supabase project and committed to this branch:

- Added `metra_role_catalogue`, `registration_requests`, and `registration_audit_events` with RLS enabled and client roles denied.
- Added one-open-request-per-user and per-user idempotency unique indexes.
- Added an append-only trigger that rejects registration audit UPDATE/DELETE.
- Added a database trigger that requires an approved, active, non-demo station owned by an active authority and an active requestable role.
- Added an atomic `submit_metra_registration` security-definer function. It was subsequently moved from `public` into the unexposed `private` schema; only `metra_api_runtime` can execute it. It writes profile, pending account state, request and audit event as one statement/transaction.
- Idempotency compares a server-computed SHA-256 digest of the normalized request payload. Reuse with a different payload is a conflict.
- Added Npgsql store and authoritative role/station catalogue adapters to the .NET API and wired the registration endpoint only when the database connection is configured.
- Added the exact applied SQL migrations to `supabase/migrations` for repository reproducibility.

### Validation performed

- .NET 10 GitHub Actions run for commit `38b595c7ff1d434e77676d1b8c47fa28c8ca24bf`: **success** (restore, build and tests).
- Supabase security advisor after the new tables: **0 findings**.
- All 15 public tables report RLS enabled.
- A non-mutating registration probe using a deliberately nonexistent station returned `station_not_available`; no account, request or audit rows were created.
- The role catalogue currently has 0 requestable roles and the station catalogue has 0 selectable stations (all 65 current stations are still pending/unverified). This is intentional fail-closed behavior, not a completed onboarding rollout.

### Remaining blockers before real registrations

1. Reconcile and approve canonical role codes and Arabic labels against the legacy role evidence; do not infer permissions from role names.
2. Verify and approve station records/coordinates and their owning authority; do not promote the current pending/unverified station rows automatically.
3. Add and test the two-stage approval persistence and trusted approver authorization adapter.
4. Add isolated PostgreSQL integration tests for idempotency races, transaction rollback and audit immutability; current CI is unit/build coverage, not database integration coverage.
5. Complete current-user context, administration queue and suspension/revocation persistence before production activation.

No legacy database operation was performed. The old project remains outside this migration path.


## Current-user context and runtime least-privilege increment

- Added the authenticated `GET /api/v1/identity/me` endpoint. It derives issuer and subject only from the validated server principal.
- Added an Npgsql data source that resolves the configured Supabase issuer plus UUID subject and reads account state, profile, approved station assignments and approved permission grants in one repeatable-read snapshot.
- Added explicit mapping for the database's `disabled` lifecycle state; unknown states remain fail-closed.
- Kept current-user data reads within the METRA public schema; provider email is not read from `auth.users` by the runtime query.
- Created the non-login PostgreSQL role `metra_api_runtime`. It has only scoped SELECT access to required METRA tables and EXECUTE on the private registration and approval RPCs. Direct EXECUTE was revoked from `service_role`, `anon` and `authenticated`.
- The actual managed LOGIN role and secret have not been provisioned. Deployment must create a dedicated login, grant membership in `metra_api_runtime`, and configure the API connection string with that login before enabling database-backed endpoints.

### Latest database checks

- 15 public tables; all 15 have RLS enabled.
- Security advisor: 0 findings.
- Function privilege probe: `metra_api_runtime` can execute the registration RPC; `service_role`, `anon` and `authenticated` cannot.
- Registration catalogue remains empty by design: 0 requestable roles and 0 selectable stations. No registration can be accepted until approved catalogue data is entered.

### CI state

- Backend build for commit `b7ce0357cd7ae7f0bd3497a86993d5c4f6c2c2fe`: success.
- .NET CI for commit `cda3634dddb7d8ec911f6317caf7e240038b012b`: **success** (restore, build and tests).


## Two-stage registration approval increment — 2026-11-03

- Added the private-schema `private.decide_metra_registration` database function. It locks the request and account state, checks the live active approver account, explicit stage-specific permission grant, station assignment scope, and persisted first-stage audit evidence.
- The decision RPC now requires the expected prior status and uses the PostgreSQL clock for validity checks and audit timestamps. Stale application reads cannot accidentally be interpreted as approval at the next stage.
- Station-stage approval rechecks that the requested station is still approved, active, non-demo and owned by an active authority, and that the requested role remains active/requestable.
- Final approval requires a distinct system approver, rechecks station and role eligibility, creates the approved station assignment, activates the account, closes the registration request and appends the immutable audit event in the same transaction.
- Rejection requires a non-empty reason; both decision stages retain the note in append-only audit history.
- Added a unique partial index preventing duplicate stage-decision audit events.
- Added trusted .NET actor resolution from live account state, approved permission grants and current station assignments. JWT subject is the actor lookup key; client role claims are not trusted.
- Added a redacted approval queue with keyset pagination and protected cursors. Queue SQL revalidates the active account, current stage permission and station scope in the same read statement.
- Added endpoints: `GET /api/v1/registration-requests/approval-queue` and `POST /api/v1/registration-requests/{requestId}/decision`. They are mapped only when the database connection is configured.
- Runtime database role now has narrowly scoped SELECT access to registration requests and approval audit evidence under RLS policies. Browser roles remain denied.
- Moved the submission RPC into the unexposed `private` schema and restricted execution to `metra_api_runtime`; service_role, anon and authenticated cannot execute it.
- Mirrored applied migrations using the exact Supabase migration versions: `20261103000835`, `20261103000914`, `20261103001045`, `20261103001209`, `20261103001354`, `20261103001407`, `20261103001654`, `20261103001743`, `20261103002006`.

### Database verification after approval changes

- New approval RPC exists and `metra_api_runtime` can execute it.
- Runtime cannot execute the obsolete five-argument approval RPC.
- Runtime has SELECT on registration requests and registration audit events, with dedicated RLS policies.
- All 15 public tables still have RLS enabled.
- Supabase security advisor: 0 findings.
- No synthetic users, roles, grants or approval records were inserted.

### Remaining release gates

1. The managed LOGIN role, secret and connection string for `metra_api_runtime` are still deployment work; no credentials were generated or exposed.
2. Configure a persistent shared ASP.NET Data Protection key ring before running multiple API replicas, so protected approval cursors remain readable across instances and restarts.
3. Approved role definitions and verified station records/coordinates are still absent. Current counts are 0 requestable roles and 0 selectable stations; the 65 station records remain unapproved/unverified for registration.
4. Add disposable PostgreSQL integration tests for both approval stages, concurrent decisions, permission revocation races, audit append-only behavior and full transaction rollback.
5. Validate deployment configuration and complete Angular/Flutter workflow integration and authenticated E2E tests before production activation.

### CI verification on latest code-bearing commit `bab18fbebaae0f30157985fbe615779e63b02577`

- .NET 10 CI: **success** (restore, build and tests).
- Backend build: **success** (API build and domain tests).
- Angular build: **success** (dependency audit, test-source type-check, unit tests and production bundle).
- Flutter CI: pending; not yet claimed as passed.


### Latest RPC privilege verification

- `private.submit_metra_registration` exists; the exposed `public.submit_metra_registration` no longer exists.
- `metra_api_runtime` can execute the private submission and approval RPCs.
- `service_role`, `anon` and `authenticated` cannot execute the private submission RPC.
- Security advisor remains at 0 findings after moving the submission function into the unexposed schema.


## Database-backed authorization increment

- Added `NpgsqlMetraAuthorizationDataSources` implementing permission-grant, resource-access and combined actor/resource authorization data sources.
- All three reads use repeatable-read PostgreSQL snapshots. The combined resource/action check loads actor lifecycle, explicit permission grant, canonical station and approved station assignments from one consistent snapshot.
- Wired the authoritative permission evaluator, resource evaluator and combined actor authorization provider only when the database connection is configured. The deny-all implementations remain the default when no database is configured.
- Permission evaluation checks current METRA account state and explicit, approved, time-bounded permission grants. It does not infer permissions from role names or JWT user metadata.
- Resource evaluation ignores the caller-provided station ID and independently resolves the canonical station from the database. The initial persistence adapter supports the `station` resource type only; all unknown resource types fail closed until reviewed mappings are added.
- Existing runtime SELECT grants and RLS policies cover the required account, grant, assignment, station and authority records; no new public access was granted.


### Final private RPC ACL verification

A catalog-level privilege check found that replacing the approval function signature had created a fresh PostgreSQL default `PUBLIC EXECUTE` ACL on the new overload. This was immediately revoked in migration `20261103001654`. The post-fix check confirms:

- `metra_api_runtime`: EXECUTE on the six-argument approval RPC.
- `anon`, `authenticated`, and `service_role`: no EXECUTE on that RPC.
- `anon`, `authenticated`, and `service_role`: no USAGE on the `private` schema.
- Among application roles, only `metra_api_runtime` can execute the private submission RPC; the PostgreSQL owner retains its inherent owner privileges.


### Runtime credential enforcement

- The API readiness endpoint now verifies that the actual PostgreSQL login inherits the privileges of `metra_api_runtime` (`pg_has_role(..., 'USAGE')`), and that the login is neither SUPERUSER nor BYPASSRLS.
- A database connection that uses `postgres`, `service_role`, or an unrelated login will remain unready instead of silently operating with excessive privileges.
- Deployment must provision a dedicated non-superuser, non-BYPASSRLS LOGIN role, grant inheritable membership in `metra_api_runtime`, and configure that login in the API connection string.


### Registration replay classification correction

- Corrected the database submission function so an already-pending request is returned as `existing_pending` before the generic linked-account check. The initial pending workflow intentionally creates the profile and account-state rows, so the previous order masked the correct outcome.
- Verified the function definition now evaluates the pending-request check before the linked-account check. No synthetic account or request rows were inserted to perform this verification.

### Verification update — 2026-11-03 01:07 UTC

- Executed the current `supabase/tests/identity_schema_contract.sql` against the target project after correcting its dollar-quote terminator. The block completed without exceptions. The identity tables correctly contain 0 account states, 0 authority memberships, 0 station assignments and 0 permission grants; no test data was written.
- Re-ran Supabase advisors: **0 security findings**. Performance advisor reports 41 informational unused-index notices on this newly provisioned/low-traffic database. No indexes were removed; usage statistics are not yet representative.
- Read-only station/observation linkage audit: 65 station rows (34 automatic, 30 classic, 1 synoptic), all pending; 50 distinct stations have coordinate rows; 1,251 observation rows have no station_id; 0 observation rows reference a non-existent station. These unlinked observations are preserved and must not be assigned to stations by name guessing.
- All four CI workflows passed on the immediately preceding commit `38543f998f256207d2bb2aafb34e9310eb6d2b3d`. The SQL-contract delimiter correction is commit `813ca1a6b1f3a7bdca4537b59b2b2dbf5cd94de0`; its four CI workflows were still running at the time of this update.
- No legacy database was accessed. No rows were inserted, updated or deleted during these checks.

### Flutter station-catalogue client increment — 2026-11-03

- Added a typed mobile station-catalogue model that preserves source-qualified identity (classic and automatic remain distinct even when display names match).
- Added a paged HTTP client with bearer-token injection through the existing access-token provider contract, bounded query validation, strict cursor checks, duplicate identity rejection, coordinate-pair validation and explicit 401/403/unavailable states.
- Added six client/model tests covering disabled-by-default behavior, missing token, mixed source rows, pagination filters, malformed coordinate/duplicate data, and forbidden/unavailable responses.
- Added `METRA_STATION_CATALOGUE_ENABLED`, default false. The client cannot be activated until the backend trusted read-store, approved station-read permission, station scope and real mobile token provider are deployed.
- This is a client foundation only: it does not make the station endpoint available, does not enable station access, and does not replace the existing fail-closed API behavior.

### Additional destination data-integrity verification — 2026-11-03

- Executed `supabase/tests/observation_import_integrity.sql` against the METRA destination. The assertion block completed without exception: no duplicate imported source identities, non-object payloads, checked identity/contact keys, demo-flagged imported observations, or missing source provenance.
- Read-only coordinate/catalogue audit: 0 orphan coordinate rows, 0 out-of-range coordinate rows, 0 partial coordinate pairs, 0 station rows missing both Arabic and English names, and 0 station rows outside the pending/unverified review state.
- These checks validate structural consistency only. They do not verify the truth of source coordinates/names or authorize station approval. All station records remain pending.
