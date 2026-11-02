# METRA 2027 — Provider-Neutral Identity API Contract

Status: proposed contract for review. This document deliberately does not select an identity provider, configure authentication middleware, or authorize a database schema change.

Related decision record: `IDENTITY-MIGRATION.md`.

## 1. Contract principles

- ASP.NET Core is the only application-facing authority for METRA profile, account state, role grants, station assignments and approval decisions.
- The identity provider is authoritative for credentials, MFA, verified identity claims, recovery and token/session lifecycle.
- Angular and Flutter consume identical versioned HTTP contracts.
- A client may submit a requested station and work role during registration, but may never submit granted permissions, approval state, authenticated actor ID or effective station scope.
- The server derives the actor from a validated identity-provider subject and resolves current METRA account and assignment records.
- Do not use browser local storage as an authorization source.
- Preserve the existing Arabic labels and original field meanings; JSON property names below are stable API names, not a request to rename legacy database columns.

## 2. Proposed endpoint inventory

All paths are under `/api/v1`. These are design contracts, not implemented routes.

| Method | Path | Purpose | Authentication |
|---|---|---|---|
| GET | `/identity/me` | Current profile, account state and effective access summary | Required |
| POST | `/registration-requests` | Submit a request for account access | Provider-specific pre-authenticated/verified flow; final policy TBD |
| GET | `/registration-requests/{requestId}` | Read own request status, or an authorized review item | Required |
| POST | `/registration-requests/{requestId}/station-decision` | First-stage station-manager decision | Required |
| POST | `/registration-requests/{requestId}/system-decision` | Second-stage system-manager decision | Required |
| POST | `/identity/sign-out` | Optional API sign-out/revocation orchestration if required by provider | Required |
| POST | `/identity/recovery/start` | Start provider-managed recovery | Anonymous, rate-limited |
| POST | `/identity/recovery/complete` | Complete provider-managed recovery | Provider token required |

Credential sign-in, MFA challenge and password recovery verification should be hosted by or delegated to the approved identity provider. METRA must not implement a second password store.

## 3. Registration request

### Request shape

```json
{
  "firstName": "الاسم الأول",
  "fatherName": "اسم الأب",
  "lastName": "الكنية",
  "stationId": "station identifier",
  "requestedRoleCode": "approved role code",
  "email": "user@example.org",
  "phone": "phone number",
  "termsAccepted": true
}
```

The legacy `password`, `confirmPassword` and `programPassword` inputs are not part of this API payload. Credential enrollment and verification must occur through the approved identity-provider flow. The user-facing label `كلمة مرور البرنامج` is retained in the migration record as legacy-only and must not become a shared secret in the new platform.

### Response shape

```json
{
  "requestId": "opaque request identifier",
  "status": "PendingStationApproval",
  "submittedAt": "ISO-8601 timestamp"
}
```

The status values are illustrative until the state machine is approved. The server validates station existence, role requestability, email uniqueness, duplicate pending requests, terms acceptance and all field constraints. It records the request and initial audit event atomically.

## 4. Current identity context

### GET /identity/me response shape

```json
{
  "userId": "opaque METRA user identifier",
  "profile": {
    "firstName": "الاسم الأول",
    "fatherName": "اسم الأب",
    "lastName": "الكنية",
    "email": "verified address",
    "phone": "phone number"
  },
  "accountState": "Active",
  "assignments": [
    {
      "stationId": "station identifier",
      "stationName": "station display name",
      "roleCode": "server-granted role code",
      "validFrom": "ISO-8601 timestamp",
      "validTo": null,
      "isActive": true
    }
  ],
  "permissions": [
    "observations.daily.create"
  ]
}
```

The response is derived server-side. It is a UI rendering context, not a bearer authorization grant. Every protected operation re-evaluates current account state, assignment validity, station scope and permission. Do not expose provider access or refresh tokens in this response.

## 5. Approval decisions

### Decision request

```json
{
  "decision": "Approve",
  "note": "Optional decision note"
}
```

The authenticated actor is never included in the request. The API derives the actor and enforces stage-specific authorization:
- Station decision: actor has an active station-manager assignment for the requested station and the station-approval permission.
- System decision: actor has the explicit system-approval permission.
- Decisions are state-checked, idempotency considered, and recorded with actor, timestamp, previous state, next state and note.
- A request cannot skip a required stage or approve itself.
- Final account activation and effective station assignment creation occur only after the approved workflow completes.

The exact state names, rejection/reopen behavior, delegation rules and notification delivery policy require product approval.

## 6. Standard error envelope

Use RFC 9457 Problem Details where possible. Validation errors should retain stable machine-readable codes and field paths.

```json
{
  "type": "about:blank",
  "title": "Validation failed",
  "status": 400,
  "detail": "One or more fields are invalid.",
  "code": "validation_failed",
  "errors": {
    "stationId": ["station_not_available"]
  }
}
```

Suggested status semantics:
- 400: malformed request or field validation failure.
- 401: missing, invalid or expired identity-provider session.
- 403: authenticated actor lacks the required permission or station scope.
- 404: resource absent or intentionally concealed from an unauthorized actor.
- 409: duplicate request or invalid lifecycle transition.
- 429: rate limit exceeded, especially registration and recovery.
- 5xx: unexpected server failure; never return credentials, tokens, stack traces or provider secrets.

## 7. Required server-side authorization sequence

For every protected request:
1. Validate the identity-provider token/session using the selected provider's supported ASP.NET Core integration.
2. Resolve the immutable provider subject to a METRA account.
3. Reject missing, pending, rejected, suspended or otherwise inactive accounts according to the approved account-state policy.
4. Load active station assignments and effective permission grants from authoritative persistence.
5. Resolve the target resource and its station scope.
6. Enforce permission, assignment validity, station match, ownership and workflow-state rules.
7. Execute the use case and audit event transactionally where state changes.
8. Return only the minimum response required by the client.

No role, station, account state, actor identifier or permission supplied in JSON, query parameters or client storage can override these values.

## 8. Current implementation gap

### Object-level authorization boundary

The API registers the policy `metra:resource-access` and a resource authorization handler. Application/endpoint code must call `IAuthorizationService.AuthorizeAsync(User, resourceDescriptor, MetraResourceAuthorizationPolicies.ResourceAccess)` for each read, update, delete, export and workflow operation that targets an individual resource. A route identifier alone never grants access.

The handler obtains the actor subject only from the authenticated server principal (`sub`, with `NameIdentifier` fallback) and delegates the decision to `IMetraResourceAccessEvaluator`. Until a production adapter is supplied, the registered bootstrap evaluator denies every resource request. The future evaluator must load the resource's actual station relationship and the actor's active station assignments/explicit grants from authoritative persistence; it must not trust the descriptor's station identifier as proof of ownership. Missing resources, unknown assignments, inactive actors and evaluator/data failures must never result in an allow decision.

No production evaluator, persistence adapter or endpoint-level invocation has been connected yet. Do not expose sensitive resource endpoints until these components and cross-station integration tests exist.

A reusable fail-closed implementation boundary is now present in `backend/Metra.Api/Security/AuthoritativeMetraResourceAccessEvaluator.cs`. It consumes a single authoritative facts result from `IMetraResourceAuthorizationDataSource` and allows only when the actor is active, the resource exists, the resource has a canonical persisted station ID, and the actor has an active assignment for that resource scope. The optional station ID on `MetraResourceDescriptor` is deliberately ignored; it is request/application metadata and cannot override persisted ownership. Missing facts and data-source failures deny access, while request cancellation is propagated. This implementation is not registered as the production evaluator because no authoritative data-source adapter exists yet; the default deny-all evaluator remains active. The data-source adapter must resolve the resource type through a server-side allowlist, derive canonical resource-to-station ownership from persistence, and evaluate current active account/assignment state in a consistent read. Endpoint-specific permission checks remain separate and mandatory.


The current API now registers a provider-neutral permission authorization catalogue in `backend/Metra.Api/Security/MetraAuthorization.cs`. It defines exact permission identifiers for station approval, system approval and daily-observation creation. Named policies require an authenticated principal and an exact `metra_permission` claim issued by the reserved internal issuer `urn:metra:internal:permissions`. That claim is reserved for server-side permissions resolved from authoritative METRA grants; claims issued by an external identity provider, provider roles or client-supplied values cannot grant a permission. The future claims-enrichment component must resolve current METRA grants from authoritative persistence and issue these claims itself on each authenticated request/session validation; stale provider role claims must never be treated as current METRA permissions.

These policies are foundations only. No identity provider, authentication scheme, claims enrichment from METRA persistence, endpoint-level permission mapping or production resource authorization is configured yet. Do not treat a role claim as a permission, and do not enable sensitive endpoints until the trusted permission-claim pipeline and resource/station checks are implemented and tested.

The inspected `backend/Metra.Api/Program.cs` currently registers Problem Details, OpenAPI and CORS, and maps health and observation-validation endpoints. It does not yet register authentication or authorization middleware, identity-provider integration, identity endpoints or persistence. The observation validation endpoints are validation-only and must not be mistaken for protected submission endpoints.

A provider-neutral domain foundation now exists in `backend/Metra.Api/Domain/Identity/`: a pure two-stage registration state machine and an authorization policy that accepts server-resolved actor/request facts. Unit tests cover the stage transitions, terminal states, station scope and explicit system-approval permission.

The application orchestration boundary is now defined in `backend/Metra.Api/Features/Identity/RegistrationApprovalApplicationService.cs`. It resolves the actor through an injected trusted-context provider, loads the request through a store interface, checks authorization and transition rules, and delegates the write to an atomic compare-and-set store operation. The store contract explicitly requires the status change, decision audit event and final-stage account/assignment activation to commit in one transaction. A concurrent status change is returned as a conflict. Unit tests cover the orchestration and ensure denied requests do not reach the commit boundary.

These contracts are not yet registered in dependency injection or wired to HTTP endpoints, identity claims, a repository or audit persistence; they do not activate accounts or write data. A production store and actor-context provider remain mandatory before enabling the flow.

Implementation of protected identity endpoints is intentionally deferred until the identity provider and the account/assignment persistence model are approved. This avoids adding a fake authentication layer or choosing a provider by assumption.

## 9. Contract acceptance tests

- Angular and Flutter deserialize the same current-user and registration response contracts.
- Client-supplied actor IDs, roles, permissions, account state and station assignments are ignored or rejected.
- Pending/suspended/rejected accounts cannot call protected endpoints.
- An expired or revoked provider session is rejected.
- Station approval is limited to the actor's active station scope.
- System approval requires its own explicit permission and cannot skip station approval.
- Duplicate pending registrations return a stable conflict response.
- A request cannot be approved twice into duplicate assignments.
- Recovery endpoints never reveal whether an email/phone pair is registered.
- Recovery is rate-limited and delegates credential handling to the provider.
- Every decision and assignment change is auditable.
- No endpoint exposes passwords, password hashes, provider secrets, refresh tokens or internal exception details.

## 10. Decisions needed to turn this proposal into implementation

1. Approve the identity provider and its ASP.NET Core validation approach.
2. Approve whether registration is open, invitation-based, or email-verified before review.
3. Approve the canonical role/permission catalogue and the exact Arabic display labels.
4. Approve account-state and two-stage approval transitions, including rejection and resubmission.
5. Approve the source of truth for station identifiers and station assignments.
6. Approve the persistence model and migration treatment of legacy users and pending registration requests.

Until these decisions are approved, keep this contract provider-neutral and do not change Supabase Auth, PostgreSQL schema, RLS, policies or existing user records.
