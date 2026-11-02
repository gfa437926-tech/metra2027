# METRA 2027 — Management API Contracts (Design Only)

**Status:** proposed application contract; not a database schema or deployment authorization.  
**Backend target:** ASP.NET Core 10.  
**Scope:** account lifecycle, two-stage approval, roles, permissions, station assignments, and audit history.

## 1. Non-negotiable boundaries

- The ASP.NET Core API is the only trusted authorization boundary. Angular and Flutter may hide controls for usability, but client state never grants access.
- Every protected request authenticates the caller and authorizes the requested action against current server-side account state, role grants, and station scope.
- Default to deny. Unknown account states, unknown permission codes, missing actor context, unavailable authorization stores, and ambiguous station identities fail closed.
- Preserve the legacy source as read-only. Do not write to, migrate, or alter the legacy database as part of this work.
- Do not implement persistence adapters or execute database changes until the owner has reviewed and explicitly approved the database schema.
- Never accept role codes, permission lists, approver identity, approval stage, or audit actor identity as trusted client-supplied authority.

## 2. Canonical application concepts

### Account

The account profile contains the original registration identity fields and contact details. Its lifecycle is separate from its authorization grants.

Account states exposed by the application contract:

- `PendingStationApproval`
- `PendingSystemApproval`
- `Active`
- `Rejected`
- `Suspended`
- `Disabled`

Only `Active` accounts may perform ordinary protected operational actions. State transitions must be explicit and validated by the server. Unknown persisted values must never be interpreted as active.

### Approval

Registration approval is a two-stage process:

1. A station-scoped approver reviews the request and either approves it for the next stage or rejects it.
2. A system-level approver makes the final decision and activates the account, or rejects it.

The API must enforce the stage order and approver scope. A station approver cannot perform the system decision. A system approver cannot bypass a missing first-stage decision. A requester cannot approve their own registration. Repeated decisions must be idempotent or return a conflict; they must not create duplicate transitions.

### Role and permission

- A role is a named, managed bundle of permission codes.
- A permission is a stable server-defined capability such as `accounts.read`, `accounts.approve.station`, `accounts.approve.system`, `roles.manage`, `permissions.read`, `stations.read`, `stations.assign`, or `audit.read`.
- Role membership and station scope are separate dimensions. A role grant without a valid station scope does not imply global access.
- The server owns the permission catalogue. Clients cannot create arbitrary permission codes or elevate themselves by editing profile metadata.

### Station assignment

An assignment links one account to one source-qualified station identity and a role for a bounded validity period. The identity is the pair `(sourceKind, sourceRecordId)`; display names are not unique keys. Classic and Automatic station records remain distinct. Missing coordinates do not invalidate an assignment and must not be fabricated.

## 3. HTTP contract proposal

All routes are under `/api/v1`. These are design contracts; route activation remains disabled until authentication, actor context, authorization services, and approved persistence are deployed.

| Method and route | Purpose | Required capability |
|---|---|---|
| `GET /identity/me` | Current caller's safe profile, account state, assignments, and display permissions | authenticated active account |
| `GET /management/accounts` | Filtered, paginated account list | `accounts.read` |
| `GET /management/accounts/{accountId}` | Account detail and lifecycle summary | `accounts.read` plus scope |
| `POST /management/accounts/{accountId}/station-decision` | First-stage approve/reject decision | `accounts.approve.station` plus matching station scope |
| `POST /management/accounts/{accountId}/system-decision` | Final approve/reject decision | `accounts.approve.system` |
| `GET /management/roles` | List roles | `roles.read` |
| `POST /management/roles` | Create a role from approved permission codes | `roles.manage` |
| `PUT /management/roles/{roleId}` | Update role metadata and permission grants | `roles.manage` |
| `GET /management/permissions` | Read the server permission catalogue | `permissions.read` |
| `GET /management/accounts/{accountId}/assignments` | Read station assignments | `assignments.read` plus scope |
| `POST /management/accounts/{accountId}/assignments` | Grant a station-scoped role | `stations.assign` plus scope |
| `DELETE /management/accounts/{accountId}/assignments/{assignmentId}` | Revoke an assignment | `stations.assign` plus scope |
| `GET /management/audit` | Filtered, paginated audit history | `audit.read` plus scope |

Mutation requests should carry an idempotency key where retries could repeat a consequential action, and an expected resource version (or equivalent concurrency token) where stale edits must be rejected. Responses must not expose password hashes, reset secrets, raw tokens, signing material, or internal security metadata.

## 4. Decision and mutation invariants

1. Resolve the actor from a verified server-side authentication principal; never from a request body or query parameter.
2. Load the target account and relevant approval state inside the same transaction as the decision.
3. Re-check actor account state, permission, approver stage, and station scope at mutation time.
4. Enforce legal state transitions on the server; do not accept a caller-supplied target state as an unrestricted update.
5. Write the business change and its audit event atomically. If audit persistence fails, the business mutation must roll back.
6. Use optimistic concurrency or an equivalent serialization strategy so two concurrent approvals cannot both win.
7. Prevent self-approval and prevent a station approver from making a system-level decision.
8. Return a stable conflict response for stale versions, duplicate decisions, or invalid transitions; do not silently overwrite.
9. Revoke or invalidate relevant sessions after suspension/disablement according to the approved session design. A profile state change alone must not be assumed to invalidate already-issued bearer tokens.
10. Do not leak whether an unrelated account exists when the caller lacks scope.

## 5. Error response shape

Use a consistent problem-details response with a stable machine-readable `code`, a safe human-readable `title`/ `detail`, and a trace identifier. Suggested codes:

- `authentication_required` — HTTP 401
- `permission_denied` — HTTP 403 (or scoped 404 where existence must be concealed)
- `resource_not_found` — HTTP 404
- `invalid_state_transition` — HTTP 409
- `concurrency_conflict` — HTTP 409
- `validation_failed` — HTTP 400
- `service_unavailable` — HTTP 503

Never return SQL errors, stack traces, provider exception messages, or secret-bearing configuration.

## 6. Audit event contract

Each security-relevant event should record, at minimum:

- event identifier and UTC occurrence time;
- verified actor identifier and actor type;
- action code and target type/identifier;
- outcome (succeeded/denied/failed);
- correlation/trace identifier;
- reason code and a bounded, sanitized reason where policy permits;
- relevant before/after state codes or a safe change summary.

Do not record passwords, access/refresh tokens, recovery codes, signing keys, or unnecessary personal data. Audit history is append-only at the application contract level; ordinary management endpoints must not edit or delete prior events.

## 7. API activation gates

A route must remain unavailable (503) until all of the following are true:

- verified authentication is configured for the target environment;
- the server constructs a trustworthy actor context;
- authorization policies are registered and tested for both permission and station scope;
- approved read/write adapters are registered;
- transactional audit behavior and concurrency behavior are tested against the approved schema;
- integration tests cover unauthorized, out-of-scope, wrong-stage, self-approval, stale-version, and concurrent-decision cases.

A disabled endpoint must not fall back to mock data, a permissive policy, or client-provided identity.

## 8. Required test matrix

| Scenario | Expected result |
|---|---|
| Anonymous caller requests a protected management route | 401 |
| Authenticated but inactive account requests an operational action | denied |
| Active account lacks required permission | 403 |
| Station approver acts outside assigned station scope | denied without data disclosure |
| Station approver attempts final system approval | 403 |
| System approver attempts final approval before stage one | 409 |
| Requester attempts to approve their own account | 403 |
| Two approvers submit conflicting decisions concurrently | exactly one valid transition |
| Retry repeats the same idempotent decision | same outcome or documented conflict; no duplicate audit transition |
| Audit write fails during a business mutation | entire mutation rolls back |
| Unknown account state or permission code is encountered | fail closed |
| Endpoint feature flag is disabled or required services are absent | 503; no mock response |

## 9. Next implementation sequence

1. Review this contract against the preserved legacy registration labels and approval workflow.
2. Obtain explicit owner approval of the physical database schema and migration plan.
3. Implement domain types and pure transition/authorization tests without database writes.
4. Implement repository interfaces and transaction boundaries.
5. Add persistence adapters and PostgreSQL integration tests only after schema approval.
6. Add verified JWT/JWKS validation and trusted actor-context construction.
7. Register protected endpoints behind explicit activation gates.
8. Connect Angular and Flutter to the live API only after end-to-end security tests pass.
