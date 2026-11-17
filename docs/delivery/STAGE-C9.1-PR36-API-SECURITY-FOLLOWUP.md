# C9.1 — PR #36 API Security Follow-up

**Reviewed head:** `94e3497830985acc5a60810fda3a93c67e9073e5`  
**Branch:** `work/backend-db-integration-full-2026-11-13`  
**Scope:** read-only source review of API authorization, privileged Supabase reads, Flutter submission wiring, and current CI evidence.  
**Decision:** follow-up blockers documented; no hosted database changes, no deployment, and no PR merge.

## 1. Current remote evidence

At review time:
- PR #36 head matched `94e3497830985acc5a60810fda3a93c67e9073e5`.
- PR remained open and unmerged; GitHub reported mergeable / clean.
- Backend build, Flutter C7 CI, and Flutter Client CI completed successfully on this exact commit.
- These results establish CI status only. They do not establish production integration or hosted database readiness.

## 2. Finding: authorization-check / privileged-read TOCTOU

### Evidence

- `ObservationQueueEndpoints` calls `HasStationPermissionAsync(userId, stationId, ...)`, then separately calls `IObservationQueueService.GetSubmittedAsync(stationId, ...)`.
- `SupabaseObservationQueueService` performs the subsequent read with the server-side `ServiceRoleKey`.
- `StationUserDirectoryEndpoints` and `StationAuditEndpoints` similarly apply `RequireStationPermission("users.station.view")` at the API layer, then their data services call privileged RPCs with station ID and limit, but no actor identity.
- The authorization middleware and privileged data operation are therefore separate operations.

### Risk

If a station permission or assignment is revoked after the authorization check but before the privileged read, the read may still complete using the service-role credential. This is a time-of-check/time-of-use race. Source inspection alone does not prove exploitability or timing in a deployed environment, but the split is not a strong atomic revocation boundary.

### Required closure

Before production acceptance, sensitive station-scoped read operations should enforce actor identity, active assignment, authority scope, and the relevant permission inside the same database transaction/RPC that returns the data. Do not rely solely on an API-side pre-check followed by a service-role read. Add concurrency tests that revoke the grant/assignment while the read is in flight and prove the required outcome.

**No SQL or hosted RPC was changed in this review.** Any implementation must first be added to the isolated schema/test path and reviewed before hosted change approval.

## 3. Finding: Flutter observation submission remains a local draft

### Evidence

- `hourly_observation_entry_screen.dart` uses a local delay and explicitly reports that the draft was saved only in the current session.
- `daily_observation_entry_screen.dart` does the same.
- Both screens state that production submission is blocked pending approved scientific field contracts.
- `MetraServiceReadiness.observationSubmit` is currently classified as `liveApi`, which does not match those two screen implementations.

### Required closure

- Keep production submission visibly disabled/not-live until the approved field contract and API integration are complete.
- Align the readiness classification with actual behavior (or split draft/local-save readiness from live submission readiness).
- Add widget/API contract tests proving that the UI does not claim a production save when no API request occurred.
- Obtain the authoritative scientific field definitions, units, precision, missing-value conventions, and validation rules before enabling submission.

No Flutter code was changed in this documentation-only follow-up.

## 4. Other reviewed controls

- The API has a fallback authenticated-user policy; health and readiness are explicitly anonymous.
- JWT validation configures issuer, audience, lifetime, signing key, and RS256/ES256 algorithms.
- Supabase HTTP clients are configured with bounded eight-second timeouts.
- Station user directory and station audit endpoints use station permission policies and read rate limits.
- Station assignment mutation routes use station-scoped permission policies and sensitive rate limits.
- Observation queue reads enforce a bounded limit and fail closed on unavailable authorization or data services.
- The archive service remains intentionally unconfigured and returns 503 after authorization checks.
- AI, Climatol, forecast centres, and electronic audit UI remain mock/non-production.

These are source-level observations, not a substitute for a deployed staging penetration test or a full SQL/RPC authorization review.

## 5. Release blockers

1. Close the authorization/read TOCTOU boundary for privileged station-scoped reads using atomic actor-aware database operations and concurrency tests.
2. Complete the real archive read model and station-bound grants in isolation; keep HTTP 503 until approved and verified.
3. Align Flutter readiness metadata with actual local-draft versus live API behavior.
4. Complete scientific field contracts and wire daily/hourly submissions to the .NET API with end-to-end tests.
5. Validate all RPC signatures, privileges, and data scopes against the approved hosted schema in staging before any production change.
6. Run staging tests with the real identity provider, deployed API origin, and Flutter dart-defines.
7. Obtain explicit approval for hosted SQL and deployment.

## 6. Change boundary

This commit is documentation only:
- No source code changed.
- No migrations or SQL proposals applied.
- No Supabase hosted schema, policies, grants, or data changed.
- No PR merge or deployment performed.

## 7. Decision

**Not Production Ready.** CI is green on the reviewed commit, but privileged read atomicity, archive implementation, live observation submission, scientific contracts, and staging validation remain open.
