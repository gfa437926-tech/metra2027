# Permission grant ceiling and observation validation audit — 2026-11-10

## Scope and safety boundary

This is a source-only review of branch `integration/repository-consolidation-audit`.
No database connection was opened. No SQL or migration was executed. The legacy
database and legacy station catalogue were not accessed or changed.

Reviewed at commit `9ae17e99003ffc47aaa9f4b159e4894a123685f5`.

## Finding 1 — observation validators are not wired into submission

### Evidence

- `backend/Metra.Api/Domain/Observations/HourlyObservationValidator.cs`
  contains field-level rules, UTC-hour-dependent required fields, and the
  dry/wet temperature relationship.
- `backend/Metra.Api/Domain/Observations/DailyObservationValidator.cs`
  contains daily field rules and the minimum/maximum temperature relationship.
- `backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs`
  validates request envelope properties through
  `ObservationSubmissionRequestGuard.GetError` (idempotency key, type,
  timestamp, JSON object and payload size), then calls the persistence service.
  The reviewed submission path does not invoke either domain validator.
- The request payload is a generic `JsonElement`; no typed hourly/daily field
  mapping or required-field selection is visible in this endpoint.

### Risk / status

**BLOCKER — domain validation is not proven to run before persistence.**
The existing validators and their unit tests do not establish enforcement on
the actual API submission path. A client can submit a syntactically valid JSON
object that has not been checked against the hourly/daily meteorological rules.

### Required implementation and verification

1. Define explicit, versioned DTOs or a typed mapping for hourly and daily
   payloads. Do not infer field names or silently rename legacy field codes.
2. Map every accepted field from the authoritative form contract and reject
   unknown fields where the contract requires strictness.
3. Invoke the corresponding domain validator in the server submission path
   before calling the persistence service.
4. Define the required daily fields from an approved report-type contract;
   do not invent a required-field list.
5. Add endpoint-level tests proving invalid hourly and daily values return
   validation errors and never invoke the persistence service.
6. Add positive endpoint tests for valid payloads, including all conditional
   UTC observation hours, precipitation hours, missing-value marker handling,
   and temperature relationships.
7. Add Flutter and Angular contract tests proving that the UI field names and
   serialized values match the server DTOs.

## Finding 2 — complete permission delegation ceiling is not proven

### Evidence

- `database/migrations/021_authority_permission_grant_lifecycle.sql`
  defines `request_authority_permission_grant`. It verifies the target is
  active and has an approved current authority membership whose role allows
  the requested permission. It records the request with
  `requested_by = p_user_id`, making the request self-service.
- `decide_authority_permission_grant` verifies an active reviewer with
  `authority.access.review` and verifies that the target's current role
  allows the requested permission. It prevents the requester/subject from
  approving their own request.
- `revoke_authority_permission_grant` requires the separate
  `authority.access.revoke` permission and prevents the subject from
  revoking their own grant.
- The reviewed decision function does not explicitly compare the permission
  being granted against a reviewer-specific delegable-permission subset,
  delegation depth, or a grantor ceiling inherited from the reviewer's own
  approved grants. The existing source audit also records the delegation
  ceiling as NOT PROVEN.

### Risk / status

**BLOCKER — a complete grantor ceiling is not demonstrated by the reviewed
source.** The target-role allow-list limits which permissions the target may
hold, but it is not equivalent to proving that the approving actor may
delegate every such permission.

The database functions are restricted to `service_role`; this reduces direct
client invocation but does not replace the missing delegation policy.

### Required implementation and verification

1. Approve an explicit delegation model defining authority scope, permission
   subset, maximum delegation depth, grant duration limits, and any
   non-delegable permissions.
2. Enforce the actor's delegation ceiling inside the same database
   transaction that approves the grant. Do not rely on API-only checks.
3. Derive the actor from a verified identity at the API boundary and ensure
   the trusted service call cannot accept an arbitrary client-supplied actor.
4. Preserve separation of requester, subject and approver; reject self-grants,
   self-approvals, inactive memberships, expired grants, and cross-authority
   scope changes.
5. Add database-level negative tests for attempts to grant a permission the
   actor does not hold or cannot delegate, cross-authority grants, elevation
   beyond the actor's role, excessive validity, and concurrent approval/revoke.
6. Add API tests proving that an actor ID supplied in a request body cannot
   override the authenticated subject.
7. Keep grant-writing unavailable until the policy and tests are reviewed.

## Required next sequence

1. Resolve the authoritative hourly/daily field contract and DTO mapping.
2. Wire the validators into the actual submission path and test the endpoint.
3. Agree the permission delegation ceiling before modifying grant approval SQL.
4. Implement and test database-enforced ceiling checks in an isolated test
   database only, after schema review and explicit approval.
5. Re-run the complete client/backend CI and review the resulting evidence.

## Explicit non-actions

- No SQL or migration was applied.
- No Supabase project was contacted or modified.
- No legacy database, legacy station data, or old project was touched.
- No pull request was merged.
