# View-data authorization source reconciliation — 2026-11-10

Repository: `gfa437926-tech/metra2027`
Branch: `work/flutter-observation-modules`
Reviewed commit: `58d8687bf3aab6fef022d91d2b30eab493076cbc`
Status: source-only finding; no authorization-policy or database-change approval.

## Confirmed role and permission evidence

1. `database/seeds/001_role_catalogue.sql` defines both `station_auditor` (مدقق محطة) and `chief_auditor` (المدقق الرئيسي العام). The seed inserts role definitions only; it does not seed a global data-review permission.
2. `docs/security/role-permission-matrix.md` assigns `observation.review` and `observation.return_for_correction` to `station_auditor`, and `observation.approve` plus `observation.return_for_correction` to `chief_auditor`. The document describes the mapping as an additional requirement in `public.metra_role_permissions`, with an individual approved grant also required.
3. The tracked migrations `003_station_permission_rpc.sql` and `015_authority_scoped_permission_rpc.sql` expose only station-scoped and authority-scoped predicates. The authority predicate explicitly requires an authority membership and grant in the exact authority; it is not a national/all-stations predicate.
4. `backend/Metra.Api/Security/StationAuthorizationService.cs` invokes the station RPC with the verified API actor ID, station ID, and permission code. It has no global-auditor method or trusted access-context contract.
5. `GET /api/v1/stations/{stationId}/observations` checks one of three permission codes against the requested station, then reads the queue in a separate service call. It does not return or resolve an auditor's all-station scope.
6. The role-permission matrix and role catalogue are not sufficient to prove the actual deployed contents of `metra_role_permissions`. In this repository snapshot, the visible `database/seeds/001_role_catalogue.sql` only seeds role definitions; the original complete permission allow-list/seed remains unreconciled.

## Decision

**Global auditor scope is still unproven.** The name and description of `chief_auditor` do not themselves grant all-stations access. Likewise, a `station_auditor` assignment is station-bound and must not be widened by inference. An authority-scoped permission, if present, would authorize only that authority and must not be described as country-wide.

Do not enable `view-data` for either role on the assumption that role labels imply scope. Keep the Flutter review destination hidden until the authoritative permission mapping and server-side scope contract are verified. Station heads must remain restricted to their single current station assignment.

## Additional API risk to resolve

The observation queue endpoint currently performs authorization and the service-role queue SELECT as separate operations. The source does not demonstrate an atomic database read that binds the queue result to the same authorization decision. This creates a time-of-check/time-of-use boundary around revocation or assignment changes. Resolve this with a narrowly scoped, server-only read RPC that validates actor, exact station, role allow-list, grant, and current assignment while selecting the queue in one database transaction, or provide an equivalent transactionally enforced design. Do not use a broad service-role SELECT as the security boundary.

The decision endpoint and all future detail/export/report endpoints require the same server-enforced scope. Client-supplied role/user/station values must never establish authority.

## Required next actions

1. Recover and verify the exact authoritative `metra_role_permissions` DDL and seed from trusted artifacts belonging to the NEW project; do not inspect or access the legacy database.
2. Determine whether `chief_auditor` has a separately approved all-stations permission, an authority-scoped permission, or no active grant. Do not infer the answer from the role name.
3. Specify the intended meaning of “all stations”: all stations in one authority, all stations in a country, or all eligible stations. Bind it to an explicit permission scope.
4. Add a trusted API access-context response derived from JWT `sub` and authoritative records; every data endpoint must independently enforce the same scope.
5. Implement the atomic queue-read boundary and add negative tests for station-head cross-station access, station-auditor escalation, unauthorized roles, revoked/expired grants, and RPC failure.
6. Add Flutter tests for auditor station selection, station-head fixed station, forbidden deep links, and hidden navigation for all other roles.
7. Run backend and Flutter CI on the final PR head before requesting review.

## Verification state at this commit

- Backend workflow run `42727016459` completed successfully on commit `8e3dc64d2696169934ec10b4c8a0346ffbd7b5e8`: restore/advisory checks, authorization SQL contract checks, API build, domain/API tests, and production container build all passed. This run is not on the current PR head.
- The check run on current PR head `58d8687bf3aab6fef022d91d2b30eab493076cbc` named `build` completed successfully. Do not interpret this as a Flutter test result.
- Flutter analyze/test execution is not verified on the current PR head. A previous client workflow failed during analyze and did not reach Flutter tests.
- PR #15 remains open and draft; it has not been merged.

## Safety boundary

No database was connected to. No SQL or migration was applied. No Supabase schema, grants, role mappings, or station data were changed. The legacy repository and legacy database were not accessed or modified. No deployment or PR merge was performed.
