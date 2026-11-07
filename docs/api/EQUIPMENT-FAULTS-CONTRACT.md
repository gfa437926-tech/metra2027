# Equipment Faults — Domain Contract (Draft)

**Status:** isolated implementation specification; not yet exposed by the API.
**Persistence:** intentionally excluded until the station catalogue and database schema are reviewed and explicitly approved.

## Trust boundaries

- Require a validated Supabase access token for every future endpoint.
- Derive the reporter identity only from the validated JWT `sub` claim.
- Never accept a reporter/user identity from a client payload.
- Resolve station access on the server for every read and mutation. A route station ID is a resource selector, not proof of authorization.
- For every operation addressed by `faultId`, load the record using both `faultId` and `stationId` (or verify its persisted `station_id` equals the route value) before applying any mutation. Never authorize against a caller-supplied station ID alone.
- Require the action-specific permission and a matching station scope. Fail closed if authorization is unconfigured, times out, returns malformed data, or denies access.
- For create operations, derive the user from JWT `sub` and authorize `equipment_fault.create` against the route station before accepting the submission.
- Keep service-role credentials server-side.
- Record every decision and transition in an append-only audit record containing actor, timestamp, previous state, next state, and reason.
- Bound request sizes, pagination, text lengths, upload types, upload sizes, and request rates.

## Implemented station-scope guard

The isolated backend now includes `EquipmentFaultStationScope.MatchesPersistedOwner`.
Record handlers must call this guard only after loading the persisted fault and must
deny the request when either station identifier is empty or the route station does
not equal the persisted owner. Unit tests cover matching, cross-station mismatch,
and empty identifiers. This helper is defense-in-depth; it does not replace the
database query constraint or the authorization service.

## Application authorization orchestration

`EquipmentFaultApplicationService` now centralizes the preconditions for creation
and record-level access:

- Creation validates the domain submission before checking
  `equipment_fault.create` for the requested station.
- Record operations obtain the owner station from
  `IEquipmentFaultStationReader`, compare it with the route station, and only then
  check the action permission.
- Lifecycle authorization uses `AuthorizeTransitionAsync`: the required permission
  is derived internally from `EquipmentFaultPolicy.TryGetRequiredPermission`, so
  clients cannot choose or weaken the permission associated with a transition.
- Invalid transitions are rejected before repository or authorization calls. Valid
  transitions still require a matching persisted station and the exact derived
  permission (for example, Submitted -> UnderReview requires
  `equipment_fault.review`).
- A missing record or station mismatch is normalized to
  `NotFoundOrWrongStation`; denied permission, dependency timeout, HTTP failure,
  malformed authorization response, and unexpected repository/authorization-provider
  exceptions fail closed. Explicit caller cancellation is propagated rather than
  converted into an authorization denial.
- The station reader is an interface only. No concrete persistence adapter, database
  object, migration, or RPC is introduced by this change.

The service is not registered as an API dependency and no HTTP endpoint is exposed
until the approved persistence contract is available.

## Proposed API surface

| Method | Route | Permission |
|---|---|---|
| POST | `/api/v1/stations/{stationId}/equipment-faults` | `equipment_fault.create` |
| GET | `/api/v1/stations/{stationId}/equipment-faults` | `equipment_fault.read` |
| GET | `/api/v1/stations/{stationId}/equipment-faults/{faultId}` | `equipment_fault.read` |
| POST | `/api/v1/stations/{stationId}/equipment-faults/{faultId}/transitions` | permission for requested transition |

## Domain validation

- Category: 2–80 characters.
- Equipment name: 2–120 characters.
- Description: 10–4000 characters.
- Occurrence timestamp is required and cannot be more than five minutes in the future.
- An operationally blocking report must have High or Critical severity.
- Station ID is taken from the route; reporter ID is taken from the authenticated principal.

## Lifecycle

```text
Submitted -> UnderReview -> Assigned -> InProgress -> Resolved -> Closed
     |              |          ^            |
     +-> Rejected   +-> Rejected +------------+
```

Allowed rework transitions: Assigned -> UnderReview and Resolved -> InProgress.
Closed and Rejected are terminal. All other transitions must be rejected as a conflict.

## HTTP behavior

- 201: report created.
- 400: invalid input.
- 401: missing or invalid authentication.
- 403: permission or station-scope failure.
- 404: unknown or inaccessible resource.
- 409: invalid lifecycle transition.
- 503: required dependency unavailable.

List endpoints must use bounded pagination and stable ordering. Cross-station unrestricted reads are prohibited.

## Explicitly out of scope pending approval

This contract does not create or alter database tables, migrations, RPCs, storage buckets, deployed API routes, or client screens. Persistence must wait for review of the approved station catalogue and explicit approval of the database schema.


### Additional lifecycle invariants

- A transition from a status to itself is always invalid, even when the actor holds every equipment-fault permission.
- `Closed` and `Rejected` are terminal: neither status may have any outgoing transition.
- Undefined status enum values are invalid and must not be treated as terminal or transitionable.
- Reopening is explicitly limited to `Resolved -> InProgress`; rejected and closed records cannot be reopened.
- These rules are domain invariants and must be revalidated against the persisted current status when a write adapter is introduced. A client-supplied status is never authoritative.


## Concurrent transition and audit write boundary

A future persistence adapter must implement `IEquipmentFaultTransitionWriter.TryTransitionAsync` as one atomic operation. It must compare the persisted owner station and current status with the caller's expected values, update the status only when both still match, and append the immutable audit event in the same transaction. A stale expected status returns a conflict; a missing record or station mismatch must not disclose another station's record. The in-memory `EquipmentFaultTransitionConcurrency` guard is an early validation aid only and is not a substitute for the atomic database predicate. No writer implementation or database object is created before schema approval.


### Transition command validation

The application transition coordinator rejects empty actor, station, or fault identifiers; undefined statuses; transitions absent from the domain matrix; and audit reasons outside 5–1000 characters or containing leading/trailing whitespace. It checks station ownership and action permission before invoking the atomic writer. The writer must still enforce station ownership and expected status in its own atomic persistence predicate. Writer failures never return an applied result; caller-requested cancellation is propagated.


### Audit entry validation

The domain exposes `EquipmentFaultAuditPolicy.Validate` for audit entries. It rejects missing fault/actor identifiers, undefined statuses, transitions not present in the lifecycle matrix, default timestamps, and reasons outside 5–1000 characters or with surrounding whitespace. This is input validation only: immutability, append-only enforcement, trusted server timestamps, and atomic coupling to the status update remain mandatory responsibilities of the approved persistence layer.


### List query bounds and station isolation

List-query validation is limited to page numbers 1–100,000 and page sizes 1–100 (default 25). Undefined status/severity filters and reversed occurrence-time ranges are rejected. The resulting offset is bounded before persistence access. These checks do not establish station authorization: the future query adapter must derive the permitted station scope from the authenticated server-side context, apply it in the database predicate before pagination/counting, and never trust a caller-supplied station identifier as authority. Counts and page metadata must be scoped to that same station to avoid cross-station disclosure.

### Station-scoped read service boundary

The isolated backend now defines `IEquipmentFaultReadStore` and
`EquipmentFaultReadService` for list and detail reads:

- Both operations require a trusted station context and the
  `equipment_fault.read` permission before calling the read store.
- List queries are validated and bounded before authorization or persistence.
  The store receives the station ID separately from filter input and must apply
  that predicate before computing totals, ordering, offset, or page size.
- Detail reads pass both `faultId` and `stationId` to the store. The service
  also verifies the returned projection contains those exact identifiers and
  normalizes a missing or mismatched record to `NotFoundOrWrongStation`.
- Invalid projections, unexpected store failures, and authorization failures
  never produce a successful read. Caller cancellation is propagated.
- The list query has no station-ID field: callers cannot widen its station scope
  by adding a filter. The future HTTP handler must resolve station context from
  the authenticated server-side principal/resource authorization, not trust a
  caller-supplied query value.

This is a contract and orchestration layer only. There is no concrete store,
DI registration, endpoint, SQL, migration, or database change pending schema
review and explicit approval.
