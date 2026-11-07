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
