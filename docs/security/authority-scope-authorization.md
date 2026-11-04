# Authority-scoped administration: implementation boundary

## Status

**Design gap confirmed; implementation is intentionally blocked pending an explicit authority-administration workflow.** The current production authorization predicate is station-scoped. It is not safe to emulate authority scope by weakening that predicate or by treating a role name as a global bypass.

## Verified current behavior

- `public.metra_user_has_station_permission(user_id, station_id, permission_code)` requires an active account, an approved/current membership in the station owner's authority, an approved/current assignment to that exact station, an active assignment role, a role-permission allow-list entry, and an approved/unrevoked/time-valid individual permission grant.
- `request_station_assignment` and `decide_station_assignment` deliberately permit only `observer` and `station_auditor`. Administrative roles are not assignable through this station-manager workflow.
- The role allow-list includes authority/system responsibilities: `network_director` + `stations.catalogue.review`; `system_admin` + `registrations.system.approve`; and `station_head` + station-level registration and staff permissions.
- System-stage registration routes currently use station-scoped authorization and station-scoped queue/audit RPCs. The transactional registration decision also enforces reviewer eligibility and distinct-reviewer constraints. Changing only the API filter would therefore be insufficient.
- The new METRA database currently has no Auth users, authority memberships, station assignments, permission grants, or registration requests. No real administrator can be inferred or provisioned from the available data.

## Required target design

Implement a separate, explicit authority-scope authorization path. It must not be a permissive fallback from station authorization.

1. **Authority membership is the administrative scope.** The authenticated user must have an active account and an approved, current membership in the exact authority owning the target station. Authority and country must both be active. A national authority must not gain cross-authority scope merely because `is_national` is true; any cross-authority mandate requires an explicit, separately reviewed policy and grant model.
2. **Role allow-list remains mandatory.** The membership role must be active and mapped to the exact requested permission in `metra_role_permissions`.
3. **Individual permission grant remains mandatory.** Require an approved, unrevoked, time-valid `permission_grants` row for the same user and permission. Never infer an individual grant from a role or JWT user metadata.
4. **No self-approval.** Membership and permission-grant approval must retain distinct requester/reviewer identities. Privileged membership provisioning must be a reviewed workflow with append-only audit events and concurrency-safe state transitions.
5. **Transactional enforcement.** Registration system-stage decision, station catalogue review, queue reads, and audit reads must each enforce the same authority boundary inside trusted database operations. An API-only check is not sufficient because service-role RPCs bypass end-user RLS.
6. **Keep station operations separate.** Station-head permissions remain station-scoped. Observer and station-auditor assignments remain restricted to the existing station assignment workflow.
7. **Fail closed.** Missing authority, station, membership, grant, or role mapping must deny. No default system administrator, seeded account, hard-coded email, or implicit first-user promotion is allowed.

## Implementation sequence

1. Define and review the authority role scope matrix with the domain owner.
2. Add versioned SQL migrations for authority-scoped permission evaluation, privileged membership request/review/revocation, and append-only audit projection. Revoke function execution from `PUBLIC`, `anon`, and `authenticated`; grant only the required server role.
3. Update transactional decision and read RPCs to enforce authority scope, exact owner authority, stage, distinct reviewer, and station/request binding while holding the relevant row locks.
4. Add API authority-permission middleware and keep JWT-derived actor identity authoritative.
5. Add SQL contract tests, API tests, cross-authority negative tests, expired/revoked-grant tests, self-approval tests, and concurrency tests.
6. Apply migrations only to the new METRA Supabase project, verify grants/RLS/advisors, then run CI and deployment.
7. Provision the first real administrator only after the owner supplies/creates a verified Auth identity and an out-of-band trusted approval path. Never fabricate `auth.users` records or credentials.

## Release gate

The system registration approval, network-director station review, and initial administrator onboarding must remain marked **not production-ready** until the authority-scope database enforcement and privileged membership workflow above are implemented and tested. A successful build or container publish does not satisfy this gate.
