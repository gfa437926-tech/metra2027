# METRA 2027 — Identity API Contract

Status: API contract proposed; Supabase Auth is the recommended identity provider; production authentication and persistence remain gated on configuration and schema review.

Related decision record: `IDENTITY-MIGRATION.md`.

## 1. Provider recommendation

Use Supabase Auth in project metra2027-angular for credential handling, identity verification, MFA and recovery. ASP.NET Core 10 remains the sole authority for METRA account state, approval workflow, role grants, station assignments and authorization. See IDENTITY-PROVIDER-DECISION.md for the read-only project findings and the security gates before enabling JWT bearer authentication. This recommendation does not authorize Auth configuration changes, signing-key rotation, or database changes.

## 2. Contract principles

- ASP.NET Core is the only application-facing authority for METRA profile, account state, role grants, station assignments and approval decisions.
- The identity provider is authoritative for credentials, MFA, verified identity claims, recovery and token/session lifecycle.
- Angular and Flutter consume identical versioned HTTP contracts.
- A client may submit a requested station and work role during registration, but may never submit granted permissions, approval state, authenticated actor ID or effective station scope.
- The server derives the actor from a validated identity-provider subject and resolves current METRA account and assignment records.
- Do not use browser local storage as an authorization source.
- Preserve the existing Arabic labels and original field meanings; JSON property names below are stable API names, not a request to rename legacy database columns.

## 3. Proposed endpoint inventory

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

## 4. Registration request

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

## 5. Current identity context

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


### Current-user context field semantics and client parity

The response above is the canonical v1 JSON contract. The provider-neutral server DTO is
`backend/Metra.Api/Features/Identity/CurrentUserContextContract.cs`; matching read-only
client models are defined in
`angular-app/src/app/core/identity/current-user-context.models.ts` and
`mobile/metra_mobile/lib/models/current_user_context.dart`.

- `userId` is the opaque METRA account identifier, never the provider subject or an email address.
- `profile` contains only the minimum profile fields needed by the clients. Optional values are JSON `null`, not omitted inconsistently.
- `accountState` is a server-defined state string. The server must use a documented allow-list; clients must not infer that an unknown state is active.
- `assignments` contains effective station assignments only, not requested or pending assignments. `validFrom` and non-null `validTo` are ISO-8601 timestamps with an explicit UTC offset (UTC `Z` preferred). The start boundary is inclusive; the end boundary is exclusive.
- `isActive` is a server-computed display hint for the response snapshot. It is not an authorization grant and may become stale immediately after the response.
- `roleCode` is a canonical server-granted role code for display and navigation only. It does not replace permission checks.
- `permissions` contains exact server-computed permission identifiers for display/navigation. It must not be populated from untrusted token claims or client input and must not be used by an API endpoint as proof of authorization.
- The authenticated provider subject is used only inside the server to resolve the METRA account. It is not returned in this payload.
- The response must not contain access/refresh tokens, password data, MFA secrets, internal grant identifiers, security answers or audit internals.

Angular and Flutter model types intentionally mirror the same camelCase field names and nullability. A client must treat missing required fields, invalid timestamps and unknown account states as a contract error rather than silently substituting a privileged/default identity.

The endpoint remains a proposed contract and is not mapped. There is no production identity provider, account repository or assignment/permission adapter. The new DTO and client model files establish type parity only; they do not create a current-user session or return fabricated data. Do not wire a demo identity or static permission list into either client.

### Refresh and stale-context behavior

A client may cache the last successfully retrieved context briefly for display, but it must clear it on sign-out, authentication failure, account switch or an explicit session-revoked response. It must not persist permissions or station assignments as durable authorization state. A failed refresh must never fall back to a previous user's context. Any protected write/read is independently authorized by the API against current authoritative state, regardless of what the UI currently displays.

## 6. Approval decisions

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

## 7. Standard error envelope

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

## 8. Required server-side authorization sequence

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

## 9. Current implementation gap

### Object-level authorization boundary

The API registers the policy `metra:resource-access` and a resource authorization handler. Application/endpoint code must call `IAuthorizationService.AuthorizeAsync(User, resourceDescriptor, MetraResourceAuthorizationPolicies.ResourceAccess)` for each read, update, delete, export and workflow operation that targets an individual resource. A route identifier alone never grants access.

The handler obtains the actor subject only from the authenticated server principal (`sub`, with `NameIdentifier` fallback) and delegates the decision to `IMetraResourceAccessEvaluator`. Until a production adapter is supplied, the registered bootstrap evaluator denies every resource request. The future evaluator must load the resource's actual station relationship and the actor's station assignment records from authoritative persistence; it must not trust the descriptor's station identifier as proof of ownership. Assignment validity must be evaluated at the request's current UTC instant using the assignment start, optional end and revocation instants; an assignment is active only when its start is at or before now and both its end and revocation are absent or strictly after now. Missing resources, unknown assignments, inactive actors and evaluator/data failures must never result in an allow decision.

No production evaluator, persistence adapter or endpoint-level invocation has been connected yet. Do not expose sensitive resource endpoints until these components and cross-station integration tests exist.

A reusable fail-closed implementation boundary is now present in `backend/Metra.Api/Security/AuthoritativeMetraResourceAccessEvaluator.cs`. It consumes a single authoritative facts result from `IMetraResourceAuthorizationDataSource` and allows only when the actor is active, the resource exists, the resource has a canonical persisted station ID, and at least one assignment has an exact ordinal station-ID match and is valid at the evaluator's current UTC instant. Start is inclusive; end and revocation are exclusive. The optional station ID on `MetraResourceDescriptor` is deliberately ignored; it is request/application metadata and cannot override persisted ownership. Missing facts and data-source failures deny access, while request cancellation is propagated. This implementation is not registered as the production evaluator because no authoritative data-source adapter exists yet; the default deny-all evaluator remains active. The data-source adapter must resolve the resource type through a server-side allowlist, derive canonical resource-to-station ownership from persistence, and return the actor's assignment records and account state in a consistent read. The evaluator applies start/end/revocation checks using an injected TimeProvider so the decision is testable and does not rely on stale client state. Endpoint-specific permission checks remain separate and mandatory.


The API registers a provider-neutral permission catalogue in `backend/Metra.Api/Security/MetraAuthorization.cs`. It defines exact permission identifiers for station approval, system approval and daily-observation creation. A named permission policy requires an authenticated principal and delegates the requested permission to `IMetraPermissionGrantEvaluator`; the handler derives the immutable subject from the validated principal and does not trust role claims or `metra_permission` claims as authorization evidence. The reusable `AuthoritativeMetraPermissionGrantEvaluator` queries one authoritative grant source for the actor's current account state and requested permission, then checks grant start, optional end and revocation instants using an injected `TimeProvider`. A permission is granted only when the account is active, the grant exists, its start is at or before now, and its end/revocation are absent or strictly after now. This permits revocation to take effect on the next authorization evaluation without waiting for an old token to expire.

The authoritative evaluator is deliberately not registered as the production implementation because no persistence adapter or verified permission schema exists. `DenyAllMetraPermissionGrantEvaluator` remains the registered default, so no action permission is granted until a trusted adapter is explicitly supplied. Missing facts and data-source failures deny; request cancellation propagates. Endpoint-level permission mapping, authentication provider integration, production resource authorization and cross-station integration tests remain pending. Permission checks and resource/station checks are separate requirements and must both pass where applicable.

The inspected `backend/Metra.Api/Program.cs` currently registers Problem Details, OpenAPI, the permission and resource authorization foundations, CORS and rate limiting, and maps health and observation-validation endpoints. It calls `UseAuthorization()` but does not yet register authentication middleware/scheme, an identity-provider integration, identity endpoints or persistence. The authorization handlers therefore remain foundations and do not authenticate requests by themselves. The observation validation endpoints are validation-only and must not be mistaken for protected submission endpoints.

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


### Combined authorization policy

For daily-observation creation in station scope, use the named policy `metra:daily-observation-create-in-station`. It requires both the canonical `observations.daily.create` action permission and the independent `metra:resource-access` requirement. The permission evaluator and resource evaluator must both allow; success of either one alone is insufficient. The endpoint must pass a server-constructed resource descriptor identifying the target persisted resource; the descriptor's optional station ID is not authoritative. This combined policy is currently a reusable authorization definition tested through `IAuthorizationService`; it is not yet mapped to a production endpoint. The configured deny-all evaluators remain the defaults.

### Consistent actor authorization context

The combined daily-observation policy uses one `MetraCombinedAuthorizationRequirement` and one `IMetraActorAuthorizationContextProvider` call. The provider receives the authenticated subject, approved action permission and resource descriptor, then evaluates account status, permission grant validity, resource existence, canonical station ownership and assignment validity from one context result. Its data-source contract requires a transactionally consistent read or an equivalently versioned snapshot.

The authoritative provider denies missing, inactive, expired, revoked or inconsistent facts, and denies source failures. It does not treat the station identifier supplied by a request as proof of access. The deny-all provider remains registered by default; no persistence adapter or protected endpoint is enabled. Tests cover the combined authorization path and time boundaries.

### Current-user context application boundary

The API now contains a provider-neutral application service in
`backend/Metra.Api/Features/Identity/CurrentUserContextApplicationService.cs`.
Its `ICurrentUserContextDataSource` contract requires lookup by the exact issuer+subject
pair from a validated server principal, and requires account, assignment and permission
facts to come from one consistent authoritative snapshot.

The service:
- rejects missing issuer/subject values and unlinked subjects without returning a METRA user;
- returns no effective assignments or permissions unless the METRA account state is exactly
  `Active`;
- treats assignment and grant start times as inclusive and end/revocation times as exclusive;
- limits context permissions to the canonical `MetraPermissions` catalogue, deduplicates
  them and sorts them deterministically;
- never uses email as the identity link key, and never returns the provider subject in the
  client response.

The service is deliberately not registered in dependency injection and no endpoint is mapped:
there is no approved provider or verified persistence adapter. A production adapter must
validate issuer+subject uniqueness, enforce verified-email disclosure policy, return a
consistent snapshot, and have integration tests for account linking, unlinking, duplicate
identity links, inactive accounts, concurrent grant revocation and station reassignment.
The source adapter must not create an account automatically from an arbitrary valid token.
Account provisioning remains a separate approved registration workflow.


### External identity linking boundary

A provider-neutral application boundary now exists in
`backend/Metra.Api/Features/Identity/IdentityLinkApplicationService.cs`.
It deliberately accepts no target METRA account ID from the caller. The actor
account is supplied only by a trusted server-side session context provider.

The trusted context separates:
- the already-authenticated METRA session and its canonical account ID;
- the issuer+subject of the *additional* external identity being linked;
- the time the METRA session was authenticated;
- the time proof-of-possession for the additional identity was verified.

Both authentication events must be no more than five minutes old and cannot be
in the future. The context provider is responsible for completing a fresh
authentication/authorization-code flow for the additional identity, validating
its issuer, signature, audience, nonce/state and protocol requirements, and
binding that proof to the existing authenticated session. The application
service does not itself validate OIDC tokens and must never be passed untrusted
issuer/subject values from a browser request.

The store contract requires an atomic uniqueness guarantee for the normalized
issuer+subject pair and an audit event in the same transaction. It distinguishes
an identity already linked to the same account from one linked to another
account and from a concurrent conflict. No automatic account creation or
email-based account matching is permitted.

This remains an application contract only: there is no provider proof adapter,
identity-link database schema, unique index, audit persistence adapter, DI
registration or HTTP endpoint. Before activation, the concrete store must
define issuer canonicalization (including trailing-slash behavior), subject
case-sensitivity, database collation, tenant/realm boundaries, account state
re-check inside the transaction, and operational handling for compromised or
retired provider identities. Unlinking is intentionally not implemented:
it needs a recovery/last-login-method policy and an auditable step-up flow.
