# METRA 2027 — Registration Submission API Contract

Status: application-service contract and guarded HTTP adapter implemented; endpoint remains intentionally unmapped; production infrastructure adapters are pending.

This document defines the first-registration request boundary shared by Angular and Flutter. It does not authorize a database migration, schema change, or production identity-provider activation.

## 1. Endpoint

Proposed route:

`POST /api/v1/registration-requests`

The route must be exposed only after the API's Supabase JWT validation and trusted actor-context provider are configured and integration-tested. The endpoint must not accept an actor ID or Auth subject from the request body.

## 2. Request

Content-Type: `application/json`

```json
{
  "firstName": "الاسم",
  "fatherName": "اسم الأب",
  "lastName": "الكنية",
  "phone": null,
  "requestedRoleCode": "ROLE_CODE",
  "requestedStationId": "STATION_ID",
  "termsVersion": "2026-01",
  "termsAccepted": true,
  "idempotencyKey": "client-generated-unique-value"
}
```

Rules:

- The authenticated identity is derived only from the validated bearer token's `sub` claim by server middleware/context.
- The API resolves the applicant's Auth UUID from that trusted context. Never accept `authUserId`, `accountId`, role grants, station assignments, permissions, or account state from the client.
- `requestedRoleCode` and `requestedStationId` are requests, not effective authorization.
- Role and station values must be validated against server-owned active catalogues.
- Terms acceptance must be explicit and associated with the exact terms version.
- The idempotency key is required and scoped to the authenticated identity. It must not contain secrets or personal data.
- Validate lengths, Unicode normalization policy, phone format, and request size at the HTTP boundary. Apply rate limits and abuse controls.

## 3. Success response

HTTP `201 Created` for a newly submitted request:

```json
{
  "code": "registration_submitted",
  "message": "تم إرسال طلب التسجيل للمراجعة.",
  "accountId": "00000000-0000-0000-0000-000000000000",
  "requestId": "00000000-0000-0000-0000-000000000000"
}
```

An exact retry using the same identity and idempotency key returns the same logical request with HTTP `200 OK` and code `registration_already_submitted`. Do not create a second account, request, or audit submission event for a replay.

## 4. Error mapping

| Application code | Suggested HTTP status | Meaning |
|---|---:|---|
| `invalid_registration` | 400 | Required fields are missing or malformed |
| `terms_not_accepted` | 400 | Terms acceptance is absent |
| `unauthenticated` | 401 | No valid authenticated identity |
| `role_not_available` | 422 | Requested role is not selectable |
| `station_not_available` | 422 | Requested station is not selectable |
| `auth_user_already_linked` | 409 | Identity is already linked to a METRA account |
| `registration_already_pending` | 409 | An outstanding request already exists |
| `registration_submission_conflict` | 409 | Concurrent request conflict; client may refresh state |
| `registration_submission_failed` | 500 | Unexpected persistence/application failure |

Error responses must use the platform's standard problem-details envelope and must not expose SQL, constraint names, tokens, internal identifiers beyond the response contract, or stack traces.

## 5. Required server execution order

1. Enforce HTTPS and validate JWT signature, issuer, audience, expiry and not-before using trusted issuer metadata/JWKS.
2. Resolve the immutable Auth subject from the validated principal.
3. Validate request shape and terms acceptance.
4. Validate requested role and station against authoritative, active catalogues.
5. Call `RegistrationSubmissionApplicationService.SubmitAsync`.
6. Persist pending account, Auth link, pending request and audit event atomically through the store contract.
7. Return a stable response; do not create effective role grants or station assignments.

The persistence transaction is a required infrastructure guarantee, not an assumption that the current service already has a database implementation.

## 6. Security and privacy requirements

- Require verified email or an approved enrollment policy before enabling submission; the exact policy remains a product/security decision.
- Apply per-IP and per-identity rate limits, bot/abuse controls, and generic responses that avoid account enumeration where appropriate. A conservative per-IP limit of five registration submissions per hour is configured for the future endpoint; production thresholds require operational review.
- Never log bearer tokens, passwords, recovery codes, MFA secrets, or full request bodies.
- Audit the event with actor subject, request/account references, UTC timestamp, correlation ID, outcome, terms version, and minimal metadata.
- Do not trust user-editable JWT metadata for role, station, approval, or permissions.
- Use a least-privilege server database identity. The browser and mobile clients must never receive a service-role secret or direct write access to METRA tables.
- Keep notification delivery outside the transaction; use a retryable outbox after the authoritative request commits.
- Do not expose the endpoint until the actor-context provider, catalogue adapter, store adapter, rate limits, and integration tests are implemented.

## 7. Implementation status

| Component | Status |
|---|---|
| Request/application command | Implemented in `RegistrationSubmissionApplicationService.cs` |
| Trusted actor-context interface | Defined; production JWT-backed adapter pending |
| Role/station catalogue interface | Defined; deployment-configuration adapter registered; authoritative active catalogue integration pending |
| Atomic store interface | Defined; PostgreSQL adapter pending |
| HTTP endpoint adapter | Implemented but deliberately not mapped in Program.cs until dependencies exist |
| OpenAPI metadata | Added to endpoint adapter; integration tests pending |
| Angular and Flutter integration | Pending |
| Database schema / migration | Not approved; no changes authorized |

## 8. Acceptance tests before endpoint release

- Anonymous request returns 401.
- Caller-supplied identity fields are rejected or ignored; the token subject remains authoritative.
- Invalid, expired, wrong-issuer, or wrong-audience JWT is rejected.
- Inactive/unknown role or station is rejected.
- Terms not accepted or stale terms version is rejected according to policy.
- Same identity + same idempotency key returns the same request.
- Same identity + different key cannot create a second pending request when one is already outstanding.
- Concurrent submissions cannot create duplicate links or requests.
- Failure at any point in the atomic store leaves no partial METRA account/request/link/audit state.
- No role grant or station assignment exists before both approval stages complete.
- Logs and error responses contain no credentials or secrets.

The endpoint adapter is in `backend/Metra.Api/Features/Identity/RegistrationSubmissionEndpoints.cs`. It is intentionally not mapped yet: the atomic store adapter is not implemented, and the catalogue adapter currently reads only deployment-controlled allowlists. Its named per-IP limiter is configured in `Program.cs`.

## 9. Current catalogue adapter boundary

`ConfigurationRegistrationSubmissionCatalogue` reads `RegistrationSubmissionCatalogue:RequestableRoleCodes` and `RegistrationSubmissionCatalogue:SelectableStationIds` from server-side configuration. Missing or empty lists fail closed; comparisons are ordinal and client-supplied labels are never used. No role codes or station IDs are seeded or guessed by the application. This adapter is a guarded interim source for controlled environments, not proof that a role or station is active in the canonical METRA catalogue. Production release still requires a read-only adapter to the approved authoritative catalogue, including active/inactive state and lifecycle changes. Do not add real station identifiers or enable the route as part of this change.
