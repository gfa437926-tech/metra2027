# METRA 2027 — Effective Permission and Station Access Contract

Status: provider- and database-independent domain contract; permission catalogue and role mapping remain unapproved. This document does not authorize schema changes or production activation.

## 1. Security model

METRA authorization is evaluated from four separate facts:

1. **Account state** — only an Active account may perform protected operations.
2. **Permission grant** — an explicit permission code is granted to the account for a defined validity interval and scope.
3. **Station assignment** — for a station-scoped operation, the account has a current assignment to that exact station.
4. **Requested operation** — the API selects the required permission and target scope from the server-side use case, never from a client-supplied permission claim.

A role is an administrative grouping/catalogue concept. A role label, including an Arabic display name, is not itself an authorization decision. The API must resolve approved role-to-permission mappings and persist explicit effective grants. No mapping is inferred by this contract.

## 2. Scope matching

- A station-scoped operation requires an explicit permission grant whose StationId exactly matches the target station.
- The same operation also requires an active station assignment to that exact station.
- A permission grant for station A never authorizes station B.
- A station assignment without a permission grant grants no operation.
- A permission grant without a station assignment grants no station access.
- A global operation (no station target) requires an explicit global permission grant whose StationId is null.
- A global grant is not a wildcard for station-scoped operations. This avoids accidental scope expansion.
- The registration workflow additionally requires separation of duties: the station-stage approver and final system approver are distinct METRA accounts. A PendingSystemApproval state without a persisted station approver is invalid for authorization.

## 3. Validity and revocation

All validity timestamps are UTC DateTimeOffset values.

- ValidFromUtc is inclusive.
- ValidUntilUtc is exclusive.
- RevokedAtUtc is exclusive: access is denied at and after the revocation instant.
- Null ValidUntilUtc means no scheduled end; it does not prevent explicit revocation.
- Invalid windows (end at or before start), non-UTC timestamps, blank identifiers and unknown account states fail closed.
- Every grant/assignment change should be append-only in audit history. Revocation should preserve the original grant/assignment record and record who revoked it, when and why; do not erase history.

## 4. Evaluation sequence

The current pure domain evaluator follows this order:

1. Validate known account state and require Active.
2. Validate the required permission code.
3. Find an exact permission + scope grant effective at the supplied UTC instant.
4. If a station is targeted, require an exact station assignment effective at the same instant.
5. Return a stable denial code; do not infer access from a role name or a client claim.

The implementation is in `backend/Metra.Api/Domain/Identity/EffectivePermissionAuthorization.cs`, with unit tests in `backend/Metra.Api.Tests/Domain/EffectivePermissionAuthorizationTests.cs`.

## 5. Required infrastructure guarantees before production

A future PostgreSQL repository and API authorization adapter must:

- load account state, grants and assignments from authoritative server-side records;
- use one consistent UTC evaluation instant per authorization decision;
- prevent stale authorization snapshots from being used for sensitive writes, by revalidating within the write transaction or using a rigorously defined authorization-version/locking strategy;
- serialize permission revocation and station reassignment against concurrent protected writes;
- enforce foreign keys and uniqueness for canonical permission codes and assignment references;
- preserve historical grants, assignments and audit events;
- avoid accepting account ID, permission code, station scope, grant state or effective timestamps from client request bodies as authoritative;
- never use JWT user-editable metadata or frontend role flags as an authorization source;
- apply least privilege to database service credentials and keep METRA tables out of direct client access.

This contract deliberately does not prescribe physical table names, SQL, RLS policies, grants or migrations. Those require a reviewed logical model and explicit approval.

## 6. Test gates

Before a production adapter is enabled, integration tests against an isolated disposable PostgreSQL instance must prove:

- a pending, suspended or disabled account cannot act even with valid grants;
- station permission and assignment are both required and exact-scope;
- global permission does not become a station wildcard;
- expiry and revocation take effect at their exclusive boundary;
- concurrent revocation cannot race a protected write into success;
- unknown/malformed permission or account states fail closed;
- audit history is committed atomically with authorization-sensitive state changes.
- resource ownership is resolved from authoritative persistence; a caller-supplied station identifier never establishes ownership.
- inactive actors, missing/unclassified resources, cross-station assignments, blank actor/resource identifiers and authoritative-store failures are denied.
- station assignment matching uses exact canonical identifiers (ordinal comparison); whitespace, case variants and look-alike identifiers do not grant access.
- request cancellation propagates through authorization reads rather than being converted into an authorization denial or retried.
- authoritative permission and assignment facts must contain UTC timestamps, valid non-empty windows, and revocation instants within the validity window; malformed temporal facts fail closed.
- authoritative station identifiers must satisfy the canonical identifier format before they can establish scope; padded or malformed identifiers fail closed.
- anonymous requests to station catalogue and detail routes receive an authentication challenge before route handlers can expose dependency-registration state or data.

The provider-neutral evaluator and HTTP boundary are covered by `StationScopedMetraResourceAccessEvaluatorTests` and `MetraAuthenticationBoundaryTests`. The authoritative permission and resource evaluators additionally validate UTC time facts, validity windows, revocation boundaries and canonical station identifiers before allowing access. Tests use fakes/TestServer and do not connect to production persistence.

No live Supabase project is used for these tests.
