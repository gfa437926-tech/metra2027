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

The target currently has these 12 public tables, all with RLS enabled:

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

Applied migrations include the station catalogue, identity/membership/assignment tables, account profile/state, provenance fields, and observation store. The security advisor returned no findings. The performance advisor returned 34 informational unused-index findings; no index was removed.

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
- Added an atomic `submit_metra_registration` security-definer function, executable only by `service_role`; it writes profile, pending account state, request and audit event as one statement/transaction.
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
- Created the non-login PostgreSQL role `metra_api_runtime`. It has only scoped SELECT access to the required METRA tables and EXECUTE on the registration RPC. Direct EXECUTE was revoked from `service_role`, `anon` and `authenticated`.
- The actual managed LOGIN role and secret have not been provisioned. Deployment must create a dedicated login, grant membership in `metra_api_runtime`, and configure the API connection string with that login before enabling database-backed endpoints.

### Latest database checks

- 15 public tables; all 15 have RLS enabled.
- Security advisor: 0 findings.
- Function privilege probe: `metra_api_runtime` can execute the registration RPC; `service_role`, `anon` and `authenticated` cannot.
- Registration catalogue remains empty by design: 0 requestable roles and 0 selectable stations. No registration can be accepted until approved catalogue data is entered.

### CI state

- Backend build for commit `b7ce0357cd7ae7f0bd3497a86993d5c4f6c2c2fe`: success.
- .NET CI for commit `cda3634dddb7d8ec911f6317caf7e240038b012b`: **success** (restore, build and tests).
