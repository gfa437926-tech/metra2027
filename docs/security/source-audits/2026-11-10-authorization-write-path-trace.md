# METRA authorization write-path trace — 2026-11-10

**Repository:** `gfa437926-tech/metra-weather-intelligence2026`  
**Branch reviewed:** `main`  
**Scope:** checked-in source review only. No database connection, SQL execution, deployment, or legacy-repository access.

## Executive finding

The repository documents a non-login PostgreSQL role named `metra_api_runtime` for an ASP.NET API, but this review could not locate a checked-in ASP.NET project, controller, endpoint, or service implementation using the available GitHub code search and targeted path checks. Code search returned no matches for `permission_grants`, `metra_role_catalogue`, `AssignRole`, `.csproj`, `permission grant`, or `aspnet`. Common candidate paths such as `backend/Metra.Api/Program.cs`, `src/Metra.Api/Program.cs`, and corresponding `.csproj` paths returned 404. This is not a complete tree enumeration and therefore does not prove that no ASP.NET source exists elsewhere or outside this repository.

The README and migration source alone do not establish an ASP.NET permission-grant write path. The grant table is readable by `metra_api_runtime`, while its direct table writes are not granted to that role. A separate server-side path using the Supabase service-role credential exists for registration and review workflows; service-role table privileges are broad and do not themselves impose a grantor delegation ceiling.

## ASP.NET runtime role

Source: `supabase/migrations/20261103000332_provision_least_privilege_api_runtime_role.sql`

- Creates `metra_api_runtime` as `NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION`.
- Grants schema usage and SELECT on account state, user profiles, station assignments, permission grants, station catalogue, authorities, and role catalogue.
- Grants EXECUTE on `public.submit_metra_registration(...)` to this role.
- Does not grant INSERT, UPDATE, or DELETE on `permission_grants`, `station_assignments`, or `authority_memberships`.
- The migration comment says a separate managed login and membership must be provisioned outside the migration. No such login or membership configuration was verified here.

**Consequence:** based on this migration, the named runtime role cannot directly create, approve, revoke, or modify permission grants or assignments through table DML. Whether an external service has a more privileged credential or calls another RPC must be established from that service's actual source and deployment configuration.

## Permission-grant write and approval path

Source: `supabase/migrations/20261102165436_add_identity_membership_and_station_assignment.sql`

The `permission_grants` table stores target user, permission code, approval state, validity interval, revocation time, requester, approver, review time, and reason. Constraints prevent self-approval and overlapping active/pending intervals for the same user and permission.

Source: `supabase/migrations/20261102165505_lock_identity_tables_and_index_foreign_keys.sql`

- RLS is enabled and client roles `anon` and `authenticated` are explicitly denied.
- The identity foundation migration grants table-level ALL to `service_role`.
- The runtime-role migration grants only SELECT to `metra_api_runtime`.

Checked Edge Function sources:
- `registration`: submits a registration request; does not create or approve permission grants.
- `registration-approvals`: reads active direct grants to determine whether the caller has `registrations.station.approve` or `registrations.system.approve`; decision writes are delegated to `decide_metra_registration`.
- `station-review`: calls the station catalogue review transaction; it is not a permission-grant administration endpoint.
- `observations`: reads station assignments and invokes station-permission checks, then calls observation transactions; no permission-grant DML route was found in this function.

No dedicated grant-administration Edge Function or grant-creation/approval RPC was identified in the checked paths. This is a bounded source finding, not proof that no external ASP.NET or operational provisioning path exists.

**Delegation ceiling status: NOT PROVEN.** There is no located implementation showing that a grantor can only issue permissions within their own authority, station scope, permission subset, and delegation depth. Do not enable a grant-writing route or expand `metra_api_runtime` as a workaround. A secure future path must validate actor identity from a verified credential, active account, actor's own delegable permission ceiling, exact scope, target eligibility, time bounds, requester/approver separation, no self-grant, no self-approval, and audit insertion in one database transaction.

## Station-assignment request, approval, and revocation

Source: `supabase/migrations/20261104033839_012_station_assignment_workflow.sql`

The station-scoped workflow is materially narrower:

1. `request_station_assignment` requires a distinct target and actor, valid reason and validity window, and the actor's `users.station.manage` permission for that exact station.
2. It requires the station and authority to be approved/active and non-demo.
3. It requires the target account to be active and the target to have an approved, current membership in the station's owning authority.
4. It accepts only `observer` and `station_auditor` assignment roles.
5. It creates a pending assignment and audit event in the same function transaction.
6. `decide_station_assignment` requires a different actor from both the target user and requester, the same station-scoped management permission, valid active station/authority, active target account, valid authority membership, and an allowed assignment role. It then changes status and writes the audit event transactionally.
7. `revoke_station_assignment` requires a different actor from the assigned user and `users.station.manage` for that station; it changes status and records the audit event.

All three functions are SECURITY DEFINER with fixed search paths. Their EXECUTE privilege is revoked from PUBLIC, anon, and authenticated, and granted to service_role.

**Consequence:** the located station assignment path does not allow a station manager to assign management/director/system roles through this workflow. The migration explicitly states that management and director roles require a separately reviewed authority-level workflow. That separate workflow was not located in the checked sources, so management-role assignment remains an unresolved control.

## Registration request and two-stage approval

Sources:
- `supabase/functions/registration/index.ts`
- `supabase/functions/registration-approvals/index.ts`
- `supabase/migrations/20261104014631_registration_authenticated_entrypoint.sql`
- `supabase/migrations/20261104015029_authenticated_registration_decision_entrypoint.sql`
- `supabase/migrations/20261104015823_restrict_registration_rpc_to_server_runtime.sql`

Submission:
- The Edge Function verifies the bearer token with Supabase Auth and derives the applicant ID from the verified user.
- The function checks requested role catalogue eligibility and station/authority availability.
- It invokes `submit_metra_registration` with the server-derived actor ID.
- The later migration revokes execution from PUBLIC, anon, and authenticated and grants execution to service_role. The wrapper checks terms version and requestable role and delegates to a private submission transaction.

Approval:
- The Edge Function verifies the reviewer's JWT and derives actor ID from the verified user.
- It requires an active METRA account and reads current, approved direct grants for station/system registration approval.
- Station-stage queue access additionally requires an approved current assignment to the station and an approved/active non-demo station.
- System-stage queue access excludes the station-stage reviewer recorded in the audit events.
- The function delegates the decision to `decide_metra_registration`.
- The private transaction is described in source comments as rechecking active account, direct grants, station assignment, and independent two-stage review. The wrapper uses database clock time.
- The registration decision RPC is service-role-only in the later migration.

The application-level grant check is useful for queue filtering, but it is not the grant-administration path. The final authority for the decision must remain the private database transaction; no conclusion about its complete current body should be inferred from the wrapper alone.

## Permission composition observation

The station permission helper `metra_user_has_station_permission` composes role permission and individual grant checks for station-scoped operations. The station directory and registration review code also contain separate direct-grant or role-derived checks. These differing authorization compositions must be deliberately standardized and tested; they should not be treated as interchangeable.

## Source recovery blocker

The migration reconciliation report still lists six applied-version source candidates absent from the current tree, including the two critical role-permission allow-list migrations:

- `20261103162707_enforce_explicit_role_permission_allowlist.sql`
- `20261103162738_seed_conservative_observation_role_permissions.sql`

The other four outstanding candidates are listed in `docs/MIGRATION_SOURCE_RECONCILIATION_2026-11-04.md`. Do not fabricate historical originals. Recover exact source from trusted artifacts or label a future catalog-derived reconstruction explicitly as reconstructed. Do not consult or modify the legacy repository/database for this task.

## Required evidence before closing this audit

1. Obtain the actual ASP.NET source repository/path and deployment artifact, or formally record that the API is not part of this repository.
2. Trace every route/service method that reads or writes `permission_grants`, `authority_memberships`, `station_assignments`, and `metra_role_catalogue`; include indirect repository methods and background jobs.
3. Identify the credential/DB role used by each route and prove it is not a project-owner or service-role bypass.
4. Prove the grantor ceiling (permission subset, authority/station scope, time bounds, no self-grant, no self-approval, independent reviewer) in the authoritative transaction, not only in UI or controller checks.
5. Recover the two role-permission source files from trusted original artifacts and reconcile all six missing migration candidates.
6. Only after source review and explicit user approval, execute the negative authorization suite against the NEW disposable METRA staging project. No production or legacy database testing.

## Safety record

No SQL was applied. No database was connected to or queried during this review. No migration was replayed. No legacy repository or legacy database was accessed. No grant, role, membership, or assignment was created or changed. No deployment was performed.
