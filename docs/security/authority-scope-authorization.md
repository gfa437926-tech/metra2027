# Authority-scoped administration: implementation boundary

## Status

**Partially implemented; not production-ready.** Migration `015_authority_scoped_permission_rpc.sql` provides a fail-closed authority-scope predicate. Migration `016_authority_scoped_station_catalogue_review.sql` wires authority scope into network station-catalogue review, including a station-owner authority precheck and a transactional database gate. The station-scoped predicate remains unchanged. Authority membership and permission-grant provisioning/review/revocation workflows are not yet implemented.

## Verified current behavior

- `public.metra_user_has_station_permission(user_id, station_id, permission_code)` remains the station-operations predicate: active account, approved/current membership in the station owner's authority, approved/current assignment to that exact station, active assignment role, role-permission allow-list entry, and approved/unrevoked/time-valid individual grant.
- `public.metra_user_has_authority_permission(user_id, authority_id, permission_code)` requires an active account, exact active authority and country, approved/current membership in that authority, active membership role mapped to the requested permission, and an approved/unrevoked/time-valid individual grant. It does not treat `is_national` as a cross-authority bypass.
- `public.metra_user_has_station_owner_authority_permission(user_id, station_id, permission_code)` resolves the station's owner authority and delegates to the authority predicate. It is executable only by `service_role`.
- `public.decide_station_catalogue_review` now locks the station, authority and country context, active account, matching approved/current authority membership, active membership role, role-permission mapping, and individual permission grant before delegating to the existing private transactional review operation. It retains the original state-transition/audit logic and is executable only by `service_role`.
- The Angular/mobile clients do not receive the service-role key. The API's catalogue-review endpoint now calls the owner-authority precheck instead of requiring a station assignment. The database RPC independently enforces the same authority boundary at decision time.
- SQL contract tests cover both authority predicates and the catalogue-review gate; API tests cover the authority RPC route and fail-closed invalid identity/station inputs.
- `request_station_assignment` and `decide_station_assignment` deliberately permit only `observer` and `station_auditor`. Administrative roles are not assignable through this station-manager workflow.
- The role allow-list includes authority/system responsibilities: `network_director` + `stations.catalogue.review`; `system_admin` + `registrations.system.approve`; and `station_head` + station-level registration and staff permissions.
- System-stage registration decision now locks the target station/authority/country, active reviewer account, exact approved/current authority membership, active role and role-permission mapping, and approved/unrevoked/current individual grant before invoking the existing two-stage transactional decision. The system queue and audit have dedicated owner-authority-gated RPCs; the API routes use the owner-authority permission filter and pass the authenticated subject to those RPCs. Station-stage registration remains station-assignment scoped.
- The new METRA database currently has zero Auth users, account states, authority memberships, and permission grants. It has 62 non-demo station records, but no real administrator can be inferred or provisioned from the available data.

## Required target design

The authority predicate must not become a permissive fallback from station authorization.

1. **Authority membership is the administrative scope.** The authenticated user must have an active account and an approved, current membership in the exact authority owning the target station. Authority and country must both be active. A national authority must not gain cross-authority scope merely because `is_national` is true; any cross-authority mandate requires an explicit, separately reviewed policy and grant model.
2. **Role allow-list remains mandatory.** The membership role must be active and mapped to the exact requested permission in `metra_role_permissions`.
3. **Individual permission grant remains mandatory.** Require an approved, unrevoked, time-valid `permission_grants` row for the same user and permission. Never infer an individual grant from a role or JWT user metadata.
4. **No self-approval.** Membership and permission-grant approval must retain distinct requester/reviewer identities. Privileged membership provisioning must be a reviewed workflow with append-only audit events and concurrency-safe state transitions.
5. **Transactional enforcement.** Every authority-scoped queue, decision, and audit operation must enforce the authority boundary inside trusted database operations. An API-only check is not sufficient because service-role RPCs bypass end-user RLS.
6. **Keep station operations separate.** Station-head permissions remain station-scoped. Observer and station-auditor assignments remain restricted to the existing station assignment workflow.
7. **Fail closed.** Missing authority, station, membership, grant, or role mapping must deny. No default system administrator, seeded account, hard-coded email, or implicit first-user promotion is allowed.

## Remaining implementation sequence

1. Complete the authority role-scope matrix and validate it with the domain owner.
2. Add privileged membership request/review/revocation and permission-grant lifecycle workflows, including append-only audit events and concurrency-safe state transitions.
3. Verify migration 017 against real authority-member test identities, including cross-authority denial and concurrent grant revocation; complete the privileged membership and grant lifecycle.
4. Add database/API negative tests for cross-authority access, expired/revoked grants, self-approval, and concurrent decisions.
5. Apply reviewed migrations only to the new METRA Supabase project, verify grants/RLS/advisors, then run CI and deployment.
6. Provision the first real administrator only after the owner supplies/creates a verified Auth identity and an out-of-band trusted approval path. Never fabricate `auth.users` records or credentials.

## Release gate

Network-director station review and system-stage registration review now have authority-scoped database gates. The feature remains **not production-ready**: authority membership and permission-grant lifecycle, real-user negative/concurrency tests, and initial administrator onboarding are still required. A successful build or container publish does not satisfy this gate.
