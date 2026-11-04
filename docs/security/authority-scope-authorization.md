# Authority-scoped administration: implementation boundary

## Status

**Partially implemented; not production-ready.** Migration `015_authority_scoped_permission_rpc.sql` adds a separate fail-closed authority-scope permission predicate. It is deployed to the new METRA Supabase project and verified there. It is not yet wired into the administrative workflows, and no authority membership provisioning/review/revocation workflow exists. The station-scoped predicate remains unchanged.

## Verified current behavior

- `public.metra_user_has_station_permission(user_id, station_id, permission_code)` requires an active account, an approved/current membership in the station owner's authority, an approved/current assignment to that exact station, an active assignment role, a role-permission allow-list entry, and an approved/unrevoked/time-valid individual permission grant.
- `public.metra_user_has_authority_permission(user_id, authority_id, permission_code)` requires an active account, the exact active authority and active country, an approved/current membership in that authority, an active membership role mapped to the requested permission, and an approved/unrevoked/time-valid individual permission grant. It does not treat `is_national` as a cross-authority bypass.
- The new function is `SECURITY DEFINER` with a fixed search path. Its execute ACL was verified as `postgres` and `service_role` only; `PUBLIC`, `anon`, and `authenticated` cannot execute it.
- The SQL contract test `database/tests/verify_authority_permission_rpc.sh` checks the key fail-closed and privilege-boundary fragments.
- `request_station_assignment` and `decide_station_assignment` deliberately permit only `observer` and `station_auditor`. Administrative roles are not assignable through this station-manager workflow.
- The role allow-list includes authority/system responsibilities: `network_director` + `stations.catalogue.review`; `system_admin` + `registrations.system.approve`; and `station_head` + station-level registration and staff permissions.
- System-stage registration routes still use station-scoped authorization and station-scoped queue/audit RPCs. The transactional registration decision also enforces reviewer eligibility and distinct-reviewer constraints. Adding the new predicate alone does not make those flows authority-scoped.
- The new METRA database currently has one authority but no Auth users, authority memberships, or permission grants. No real administrator can be inferred or provisioned from the available data.

## Required target design

The authority predicate must not become a permissive fallback from station authorization.

1. **Authority membership is the administrative scope.** The authenticated user must have an active account and an approved, current membership in the exact authority owning the target station. Authority and country must both be active. A national authority must not gain cross-authority scope merely because `is_national` is true; any cross-authority mandate requires an explicit, separately reviewed policy and grant model.
2. **Role allow-list remains mandatory.** The membership role must be active and mapped to the exact requested permission in `metra_role_permissions`.
3. **Individual permission grant remains mandatory.** Require an approved, unrevoked, time-valid `permission_grants` row for the same user and permission. Never infer an individual grant from a role or JWT user metadata.
4. **No self-approval.** Membership and permission-grant approval must retain distinct requester/reviewer identities. Privileged membership provisioning must be a reviewed workflow with append-only audit events and concurrency-safe state transitions.
5. **Transactional enforcement.** Registration system-stage decision, station catalogue review, queue reads, and audit reads must each enforce the same authority boundary inside trusted database operations. An API-only check is not sufficient because service-role RPCs bypass end-user RLS.
6. **Keep station operations separate.** Station-head permissions remain station-scoped. Observer and station-auditor assignments remain restricted to the existing station assignment workflow.
7. **Fail closed.** Missing authority, station, membership, grant, or role mapping must deny. No default system administrator, seeded account, hard-coded email, or implicit first-user promotion is allowed.

## Remaining implementation sequence

1. Define and review the authority role scope matrix with the domain owner.
2. Add privileged membership request/review/revocation and permission-grant lifecycle workflows, including append-only audit events and concurrency-safe state transitions.
3. Update transactional decision and read RPCs to enforce authority scope, exact owner authority, stage, distinct reviewer, and station/request binding while holding the relevant row locks.
4. Add API authority-permission integration and keep JWT-derived actor identity authoritative.
5. Add database/API negative tests for cross-authority access, expired/revoked grants, self-approval, and concurrent decisions.
6. Apply reviewed migrations only to the new METRA Supabase project, verify grants/RLS/advisors, then run CI and deployment.
7. Provision the first real administrator only after the owner supplies/creates a verified Auth identity and an out-of-band trusted approval path. Never fabricate `auth.users` records or credentials.

## Release gate

The system registration approval, network-director station review, and initial administrator onboarding must remain marked **not production-ready** until the authority membership lifecycle, transactional enforcement, API integration, and real-user tests above are implemented and verified. A successful build or container publish does not satisfy this gate.
