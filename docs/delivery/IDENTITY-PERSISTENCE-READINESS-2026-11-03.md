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
