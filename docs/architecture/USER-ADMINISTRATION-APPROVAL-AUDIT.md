# METRA 2027 — User Administration and Approval Workflow Audit

Status: legacy behavior inventory and target-control requirements. This document does not approve a role matrix, registration policy, database schema or production workflow.

## 1. Registration request lifecycle observed in `login.js`

The legacy `handleRegister()` function:
1. Reads the original profile fields: `first_name`, `father_name`, `last_name`, `email`, `phone`, `station`, `role`.
2. Also reads `password`, `confirmPassword`, `program_password` and the terms checkbox.
3. Checks the program password in browser code against a hard-coded literal. This is a client-side gate and must not be carried into the replacement.
4. Checks for an existing email in `users` and `registration_queue`.
5. Hashes the submitted password in browser code.
6. Inserts a `registration_queue` row with profile values, `password_hash`, `status: 'pending'`, `program_password`, `agreed_to_terms` and `created_at`.
7. Displays a two-stage approval explanation and attempts to notify the active `رئيس محطة` matching the requested station.

This is observed legacy implementation, not a recommended security design. In particular, duplicate checks and approval writes must be enforced transactionally on the server, not trusted to browser code.

## 2. Two-stage account approval observed

The registration confirmation text says:
1. The request is reviewed by the station manager.
2. After station-manager approval, it is sent to the system manager.
3. After final approval, the applicant receives an email notification.

The station-manager notification lookup selects an active row from `users` matching both:
- `station = requested station`
- `role = 'رئيس محطة'`
- `status = 'active'`

It uses `.single()`, so the legacy code implicitly expects one matching active station manager. It does not define how multiple managers, no manager, manager absence, reassignment or delegation should be handled.

At login, the legacy code checks two booleans on the user row:
- `approved_by_station_manager`
- `approved_by_system_manager`

If the first is false, the user is told that station-manager approval is pending. Otherwise, if the second is false, the user is told that system-manager approval is pending. This reveals the two approval gates, but the inspected source does not establish a complete transition history, rejection path, appeal path, reviewer comments or atomicity guarantees.

Do not assume that `status` and the two approval booleans form a complete or consistent state machine. The exact interaction between `status`, the booleans and any legacy approval columns still needs inspection against the actual schema and management screens.

## 3. Important evidence gap: management screens

The repository tree inspected for this audit did not expose the expected legacy manager HTML files at the guessed root paths (for example, `managers/manager-dashboard.html`, `managers/center-manager.html` and `managers/station-manager.html`). The JavaScript references these paths, but their presence and actual management behavior have not been verified from those guessed paths.

Therefore this audit does not claim to know:
- the exact UI actions available to station or system managers;
- whether a request can be rejected, returned, edited or reopened;
- whether approvals can be revoked;
- whether a station manager can act outside their own station;
- how the system-manager queue is filtered;
- whether role or station changes require a second approval;
- what audit records are persisted for each decision.

These are open evidence items, not assumed behavior.

## 4. Legacy authorization weaknesses

### `auth-manager.js`
The browser-side manager:
- reads `currentUser` from `localStorage`;
- treats a 24-hour timestamp as session expiry;
- compares a stored `user.role` string with a requested role;
- exposes `hasPermission` and `hasAnyPermission` as role-string comparisons;
- hides elements using `data-role`;
- intercepts selected manager links based on a hard-coded page-to-role map;
- merges arbitrary `newData` into the stored user object in `updateUserData()`.

These are UI conveniences only. Browser storage, route names, hidden elements and client-side role values are user-controlled and cannot authorize API operations.

The role maps in `login.js` and `auth-manager.js` are not identical. For example, they do not contain the same set of redirect entries. This reinforces that neither map is a canonical role catalogue.

### `user-manager.js` and `user-data.js`
The legacy user managers can read cached/local/session data and, in one path, query Supabase directly from the browser. `user-data.js` also supplies default role/station values and can synthesize station metadata. These defaults are not valid evidence of an actual grant or assignment.

## 5. Observation workflow is a separate approval domain

The current API domain model defines observation statuses:
- `Draft`
- `Submitted`
- `Returned`
- `Approved`

And transitions:
- Draft → Submitted
- Returned → Submitted
- Submitted → Returned
- Submitted → Approved

The API authorization policy requires a server-derived actor context, active station assignment, station match and explicit observation permission. It also restricts editing/submitting to the observation creator.

Important implementation boundary:
- The observation workflow and authorization policy exist as domain code.
- The inspected `ObservationValidationEndpoints` expose validation-only routes.
- The inspected endpoints do not yet implement persistence, authenticated submission, return or approval commands.
- The Angular observation workflow component uses in-memory demo records and explicitly reports that state changes are preview-only and not saved to the server.

Do not confuse observation approval with account-registration approval. They are separate workflows with different resources, actors, permissions and state transitions.

## 6. Target requirements for registration and administration

The replacement should implement the following only after the business rules are approved:

### Registration request
- Preserve the original profile field names and Arabic labels.
- Treat the requested role and requested station as applicant-provided requests, not grants.
- Delegate credential creation and recovery to the selected identity provider; do not store another password hash in the application database.
- Enforce uniqueness, validation, rate limits and anti-abuse controls on the server.
- Never expose a shared program password in browser code.
- Return a non-enumerating response where appropriate so account existence is not disclosed.

### Approval decisions
- Record each decision with request ID, decision type, actor identity, actor's effective authority/scope, timestamp and optional reason.
- Derive the actor and station scope from authenticated server-side identity and persisted assignments.
- Enforce that a station manager can decide only within their authorized station scope.
- Enforce system-manager review only after the required station decision.
- Make decisions atomic and idempotent; prevent duplicate or out-of-order approvals.
- Define rejection, return-for-correction, cancellation, expiry and resubmission behavior before implementation.
- Preserve the full decision history; do not overwrite the only evidence of an earlier decision.
- Define behavior for zero or multiple station managers, manager leave/absence and reassignment.
- Send notifications after the authoritative transaction succeeds; notification failure must not silently reverse or duplicate the decision.

### Effective access
- Keep these concepts separate:
  1. identity-provider account state;
  2. METRA user profile;
  3. registration request state;
  4. requested role/station;
  5. granted role/permissions;
  6. active station assignments;
  7. approval/audit history.
- A successful registration approval must not automatically imply broad access to all stations.
- Every protected API operation must authorize the effective permission and resource scope on the server.

## 7. Decisions and source evidence still required

1. Confirm the exact account states and whether both approval gates are mandatory for every registration type.
2. Confirm who may approve/reject/return requests and the scope of each actor.
3. Confirm the exact rejection and correction path, including whether the applicant can edit and resubmit.
4. Confirm whether `مدير النظام` is a role, an approval responsibility, or both.
5. Confirm whether `رئيس محطة` is assigned to exactly one station and how deputy/multiple managers are handled.
6. Inspect the actual manager pages and database schema/constraints to reconcile all status and approval columns.
7. Reconcile all role labels and station values against actual records, without exporting password hashes, tokens or secrets.
8. Decide the identity provider and registration policy before implementing credential or session endpoints.

## 8. Acceptance criteria

- Applicant-supplied role/station never grants permissions by itself.
- Station decision is impossible outside the reviewer's effective station scope.
- System decision is impossible before the required prior decision.
- Each decision records actor, scope, time and outcome.
- Repeated requests do not create duplicate transitions or notifications.
- Rejection/correction/resubmission behavior is explicit and test-covered.
- Browser localStorage changes cannot grant access to a protected API operation.
- Registration approval and observation approval have separate state machines and authorization policies.
- Client applications consume server-authoritative identity, grants and station assignments.
- No database migration is applied until the complete schema and migration plan are reviewed and approved.

## 9. Scope of this change

Documentation only. No legacy application code, Supabase tables, RLS policies, Auth settings, users or credentials were changed.
