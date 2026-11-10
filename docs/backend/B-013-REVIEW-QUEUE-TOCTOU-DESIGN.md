# B-013 — Review Queue TOCTOU Security Design

- Repository: gfa437926-tech/metra2027
- Owner: Assistant 02 — Backend / API
- Reviewed at (UTC): 2026-11-10T23:31:49Z
- Status: design review documented; implementation pending schema review and owner approval
- Scope: station-scoped submitted-observation review queue
- Explicit exclusions: no SQL, migration, RPC deployment, Supabase mutation, production access, or client changes

## 1. Source inspection

The current request path is:

1. `GET /api/v1/stations/{stationId}/observations` is mapped in `backend/Metra.Api/Features/Observations/ObservationQueueEndpoints.cs`.
2. The endpoint reads the verified JWT `sub` claim as `userId`.
3. It calls `IStationAuthorizationService.HasStationPermissionAsync` sequentially for `observation.review`, `observation.approve`, and `observation.return_for_correction`.
4. If one check succeeds, it calls `IObservationQueueService.GetSubmittedAsync(stationId, limit, cancellationToken)`.
5. `SupabaseObservationQueueService` then performs a separate service-role PostgREST GET against `metra_observations`, filtered by `station_id` and `status=submitted`.

The permission RPC and queue SELECT are separate network/database operations. A revocation or assignment change can commit between them. The queue SELECT does not receive the actor ID and does not independently verify the actor's current station permission.

## 2. Threat and impact

- Threat: an authenticated reviewer has a valid permission at authorization-check time, but that permission is revoked before the subsequent queue read.
- Impact: the in-flight request may return submitted observations after the revocation has committed.
- Boundary: this finding concerns the review-queue read path. It is not evidence that an unauthenticated caller can reach the endpoint; the API fallback authorization policy still requires authentication.
- Classification: authorization TOCTOU / stale authorization window; treat as P1 until the atomic read is implemented and race-tested.

## 3. Required security invariant

For every returned queue row, the server-side data operation must establish, as one database-side atomic unit:

- actor ID equals the `sub` claim from the validated access token;
- requested station ID is non-empty and is the exact scope being authorized;
- actor currently has at least one queue-read permission accepted by policy;
- row belongs to that same station and is in the submitted state;
- page size is bounded (current API contract: 1–100; default 50);
- no rows are returned if identity, permission, scope, dependency, or result validation fails.

The service-role key remains server-only. A client-supplied user ID or station ID must never be treated as proof of authorization.

## 4. Preferred design for owner/schema review

Introduce a narrowly scoped database-side read operation (RPC/read model) that accepts the authenticated actor ID, station ID and bounded limit, and performs authorization plus queue selection in one transaction.

Suggested conceptual contract (not deployed and not approved SQL):

- Operation: `metra_get_station_observation_review_queue`
- Inputs: `p_user_id`, `p_station_id`, `p_limit`
- Authorization: evaluate the same approved permission set used by the API (review, approve, return-for-correction) against current active assignments/grants.
- Selection: return only submitted observations for exactly `p_station_id`, with a stable deterministic order and bounded page size.
- Denial: return an explicit permission-denied result or a result shape that the API maps to 403; never return partial rows on denial.
- API service: pass `userId` obtained from the validated JWT and `stationId` from the route; do not call the standalone permission RPC before this read.
- API mapping: preserve 401 for missing/invalid identity, 403 for denied scope, 400 for invalid limit, and 503 for dependency failure.

The database design must be reviewed against the actual schema before implementation. In particular, confirm the assignment/grant tables, active/revoked semantics, permission inheritance, indexes, ownership model and existing authorization RPC behavior.

## 5. Concurrency and revocation semantics

A single RPC call removes the application-level gap, but the owner and database reviewer must still choose and document the required revocation guarantee:

- Minimum linearizable behavior: the queue read and permission decision share one database transaction/snapshot. A request whose authorization/read operation linearizes before revocation may complete; a request starting after revocation commits must be denied.
- If policy requires revocation to block any overlapping read, use a consistent row-locking/serialization strategy for the relevant active grant/assignment rows and revocation writes. Define lock order to avoid deadlocks, and use bounded retry for serialization failures.
- Do not claim that merely wrapping two ordinary READ COMMITTED statements in a transaction is sufficient without defining the snapshot and locking semantics.

The decision endpoint must independently re-check the actor's decision-specific permission inside the same atomic database operation that changes observation status. Queue-read permission alone must not authorize approval or return-for-correction.

## 6. Alternatives considered

| Option | Assessment |
|---|---|
| Keep current two-call authorization then SELECT | Reject: retains TOCTOU window. |
| Add another API-side permission check | Reject: adds checks but cannot make the check/read atomic. |
| Rely on service-role PostgREST filtering by station ID | Reject: station filter is data scoping, not actor authorization; service-role access bypasses normal user RLS context. |
| Use user JWT/RLS end-to-end | Potentially viable only after confirming policy/schema and server trust boundaries; not assumed compatible with current server-side service-role design. |
| One reviewed RPC/read model with explicit actor/scope validation and atomic row read | Preferred, subject to schema review and owner approval. |

## 7. Required verification before closing B-013

1. Unit tests: map permission denied, invalid actor/station, malformed RPC response, timeout and dependency failure to fail-closed API outcomes.
2. Integration tests: a user with no grant cannot read; a user with a grant for station A cannot read station B; a grant revoked before the RPC starts cannot read.
3. Concurrency test: race queue read against revocation and assert the documented linearization/locking guarantee.
4. Decision tests: reviewer with queue-read permission but without approve permission cannot approve; the inverse permission does not grant unrelated actions.
5. Regression: pagination bounds and submitted-only filtering remain enforced.
6. CI: run the API and database integration test suites against an approved isolated test schema; do not use production data.

## 8. Approval gates and current disposition

- No schema or migration files were changed.
- No SQL, RPC, RLS, seed or Supabase operation was executed.
- No database schema was inferred or fabricated.
- The current source-level finding is confirmed; remediation is not complete.
- Required before implementation: owner approval of the schema review and the chosen revocation/concurrency guarantee.
- B-013 remains **in progress**, not completed.

## 9. Files inspected

- `backend/Metra.Api/Features/Observations/ObservationQueueEndpoints.cs`
- `backend/Metra.Api/Security/StationAuthorizationService.cs`
- `backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs`
- `backend/Metra.Api/Program.cs`
- `docs/backend/API-BACKEND-AUDIT-2026-11-11.md`
- `واجهات/مهما.md`
- `واجهات/تغيير.md`
- `docs/progress/assistant-02.md`
