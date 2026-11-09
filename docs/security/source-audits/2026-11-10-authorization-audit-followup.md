# Authorization audit follow-up — ASP.NET inventory, delegation ceiling, source recovery, and test readiness

Date: 2026-11-10  
Repository: `gfa437926-tech/metra-weather-intelligence2026`  
Branch: `main`  
Boundary: repository-only review. No legacy repository or database access, no database connection, no SQL execution, no migration replay, and no deployment.

## 1. ASP.NET service inventory

The repository migration `20261103000332_provision_least_privilege_api_runtime_role.sql` explicitly describes `metra_api_runtime` as the non-login role intended for the ASP.NET runtime. It says a separate managed login and role membership must be provisioned outside the migration and warns against using `postgres` or `service_role`.

The role is granted SELECT on account state, profiles, station assignments, permission grants, station catalogue, authorities, and role catalogue. It is granted EXECUTE on `submit_metra_registration(...)`. It is not granted table DML on permission grants, authority memberships, or station assignments by this migration.

### Search and path checks

- Repository metadata confirms the repository is public, default branch `main`; GitHub reports no code-search-index availability value (`is_code_search_indexed: null`).
- GitHub code-search queries for `Program.cs`, `ControllerBase`, `AddScoped`, `IHostedService`, `BackgroundService`, `permission_grants`, `request_station_assignment`, `decide_station_assignment`, and `metra_role_permissions` returned no indexed matches.
- Targeted fetches of likely solution/project/controller locations (including `Metra.sln`, `backend/Metra.Api/Program.cs`, `backend/Metra.Api/Metra.Api.csproj`, `src/Metra.Api/Program.cs`, `src/Metra.Api/Metra.Api.csproj`, and likely permissions controller paths) returned 404.
- These checks do **not** amount to a complete repository tree enumeration because the available GitHub connector exposes no tree/list-contents operation here and code-search indexing is not confirmed.

**Conclusion:** the actual ASP.NET source location and deployment artifact are still unverified. Do not claim the service is absent. Obtain the API repository/branch or a source/deployment artifact from its owner before enumerating Controllers, Services, Repositories, hosted/background jobs, scheduled functions, and secret/credential bindings. If ASP.NET is intended to be in this repository, restore it here before claiming a complete source audit.

## 2. Delegation ceiling inside authoritative transactions

### What is proven for station assignment

Source: `supabase/migrations/20261104033839_012_station_assignment_workflow.sql`

- `request_station_assignment` accepts only `observer` and `station_auditor`; it rejects self-targeting; checks `users.station.manage` for the exact station; verifies active station/authority, active target account, and current approved authority membership; and writes the pending assignment and audit event in the same function transaction.
- `decide_station_assignment` locks the pending row, rejects the target and requester as approver, rechecks station-scoped permission and target eligibility, restricts the role again to observer/station_auditor, and writes the decision and audit event transactionally.
- `revoke_station_assignment` rejects self-revocation, checks station-scoped management permission, and writes the revocation and audit event transactionally.
- All three functions are SECURITY DEFINER with a fixed search_path; EXECUTE is revoked from PUBLIC, anon, and authenticated and granted to service_role.

### Critical trust boundary

These RPCs receive `p_actor_user_id` as an argument and are executable by `service_role`. The SQL body evaluates permissions for that supplied UUID; it does not independently bind that UUID to an end-user JWT. Therefore, the database-side role/scope checks are effective only if the trusted service derives actor ID from a verified bearer token and never accepts a client-supplied actor ID. A compromised or incorrectly implemented service-role caller could supply another actor UUID. This caller-binding invariant must be tested at every service boundary and documented in the eventual ASP.NET source audit.

### What is not proven

- No permission-grant create/approve/revoke transaction was located.
- No authority-level management-role assignment workflow was located.
- No complete grantor ceiling (delegable permission subset, scope, validity window, delegation depth, no self-grant, no self-approval, independent reviewer) is established for permission grants.
- `metra_api_runtime` has SELECT-only access to the grant/assignment tables in the reviewed migration; do not broaden it to DML as a temporary fix.
- `service_role` has broad table privileges in the identity foundation migration; it is a trusted server credential, not a suitable user-level authorization boundary.

**Result:** the station assignment path is constrained to two non-management roles, but the overall administrator delegation ceiling remains **unproven** until the ASP.NET caller paths and a permission-grant administration transaction are located and audited.

## 3. Six migration-source candidates

The reconciliation file `docs/MIGRATION_SOURCE_RECONCILIATION_2026-11-04.md` reports 51 SQL files in current main and six outstanding source-recovery candidates:

1. `20261102172226_create_provenance_preserving_observation_store.sql`
2. `20261103122944_grant_runtime_station_coordinate_read.sql`
3. `20261103123005_link_membership_and_assignment_roles.sql`
4. `20261103123127_index_role_catalogue_foreign_keys.sql`
5. `20261103162707_enforce_explicit_role_permission_allowlist.sql`
6. `20261103162738_seed_conservative_observation_role_permissions.sql`

Repository commit-history searches for each exact filename stem returned no matching commits. Current code-search queries for the two critical `metra_role_permissions` migrations returned no indexed matches. No exact original SQL was recovered in this pass.

The two critical files remain:
- `20261103162707_enforce_explicit_role_permission_allowlist.sql`
- `20261103162738_seed_conservative_observation_role_permissions.sql`

No replacement or reconstructed historical SQL has been fabricated. Per the current project boundary, no legacy repository/database was accessed to search for these files. Recovery is limited to trusted artifacts supplied for this independent repository, its own reachable Git history, approved deployment backups, or developer-owned copies explicitly provided for review. If the exact originals cannot be obtained without accessing the legacy environment, preserve the gap and prepare a clearly labelled reconstructed baseline only after the current NEW staging catalog has been explicitly approved for read-only inspection.

## 4. Executable negative-test readiness

The existing `docs/ROLE_AUTHORIZATION_NEGATIVE_TEST_PLAN.md` defines 43 negative scenarios. It is a test plan, not an executed suite. This pass did not create a live-database test harness or run database authorization tests.

Before staging approval, the safe preparation tasks are:
- turn the 43 scenarios into executable SQL/pgTAP or isolated integration tests against a disposable schema/database, not the protected live project;
- include caller identity binding tests for every service-role RPC;
- include grantor-ceiling tests and assert that unauthorized requests leave both business rows and audit rows unchanged;
- include station and authority cross-scope tests, expired/future grants, disabled accounts, role-only/direct-grant-only composition cases, self-grant/self-approval, requester/approver separation, and management-role escalation;
- make the suite fail closed when a required grant-management function or role-permission source is missing;
- capture database function owner, SECURITY DEFINER, fixed search_path, proacl, schema CREATE rights, and role memberships as test preconditions.

**Execution gate:** do not connect to or mutate the NEW METRA staging project until the user explicitly approves that test run and the exact staging project/ref is confirmed. Use synthetic identities and data only. No production and no legacy testing.

## Current status

| Workstream | Status |
|---|---|
| ASP.NET source location and deployed artifact | Not verified; source/tree indexing limitations recorded |
| Controllers/services/repositories/background jobs | Cannot complete until actual ASP.NET source is supplied/located |
| Station-assignment SQL transaction | Source reviewed; caller identity binding still depends on trusted backend |
| Permission-grant administration and delegation ceiling | Not found / not proven |
| Six migration-source candidates | Still outstanding; exact originals not recovered |
| 43 negative scenarios | Plan exists; executable database suite not yet implemented or run |
| NEW staging execution | Waiting for explicit approval |

## Safety record

No legacy repository or database was accessed. No database was connected to, queried, or modified. No SQL or migration was applied or replayed. No credentials were read. No deployment was performed. No staging tests were run.
