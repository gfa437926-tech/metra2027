# Equipment Faults — API Contract (Draft)

**Status:** contract proposal; not yet exposed by the API.  
**Scope:** meteorological equipment faults reported by a station. This contract is intentionally independent of any database schema.

## Security invariants

- Require a valid Supabase access token on every endpoint.
- Derive reporter identity from the validated JWT `sub` claim; never trust a client-supplied reporter ID.
- Require station-scoped permissions: `equipment_fault.create`, `equipment_fault.read`, `equipment_fault.review`, `equipment_fault.assign`, and `equipment_fault.resolve`.
- Enforce station scope on every read and mutation. A station manager cannot access another station by changing a route ID.
- Record actor, timestamp, previous state, next state, and reason for every transition in an append-only audit trail.
- Keep service-role credentials server-side. Never return storage keys, secrets, or internal exception details.
- Apply bounded request sizes, strict text limits, rate limits, and attachment content/type/size checks.

## Proposed endpoints

| Method | Route | Permission | Purpose |
|---|---|---|---|
| POST | `/api/v1/stations/{stationId}/equipment-faults` | `equipment_fault.create` | Submit a report |
| GET | `/api/v1/stations/{stationId}/equipment-faults` | `equipment_fault.read` | Paginated station queue |
| GET | `/api/v1/stations/{stationId}/equipment-faults/{faultId}` | `equipment_fault.read` | Read one report |
| POST | `/api/v1/stations/{stationId}/equipment-faults/{faultId}/transitions` | transition-specific | Review, assign, start, resolve, close, or reject |

## Submission payload

```json
{
  "equipmentCategory": "أجهزة الرصد",
  "equipmentName": "مقياس الحرارة",
  "description": "توقف الجهاز عن إرسال القراءات منذ بداية الوردية.",
  "severity": "High",
  "occurredAt": "2026-11-05T07:40:00Z",
  "isOperationallyBlocking": false
}
```

The station ID comes from the route; reporter identity comes from the authenticated token. Neither is accepted as authoritative client input.

## Lifecycle

```text
Submitted -> UnderReview -> Assigned -> InProgress -> Resolved -> Closed
      |             |           ^           |
      +-> Rejected  +-> Rejected +-----------+
```

Allowed rework paths: Assigned -> UnderReview and Resolved -> InProgress. Closed and Rejected are terminal. Other transitions return `409 Conflict`.

## Validation and response rules

- Station and authenticated reporter identities must be valid.
- Category: 2–80 characters; equipment name: 2–120; description: 10–4000.
- Occurrence time is required and cannot be more than five minutes in the future.
- A report marked operationally blocking must have High or Critical severity.
- Return `201 Created` with a server-generated fault ID on success.
- Return `400` for invalid fields, `401` for invalid authentication, `403` for permission/station-scope failure, `404` for an unknown or inaccessible report, `409` for invalid transitions, and `503` when a required dependency is unavailable.
- Lists use bounded pagination and stable ordering. No unrestricted cross-station queries.

## Not implemented yet

This contract and the domain policy do not create tables, RPCs, storage buckets, API routes, or client screens. Before persistence is implemented, review the contract and storage design against the approved station catalogue and explicitly approved database schema. No Supabase schema has been changed.

## Workshop assignment rules (domain groundwork)

The current domain policy additionally validates a maintenance assignment independently of persistence:
- fault, station, and assignee identifiers must be non-empty;
- assignment time must be present and no more than five minutes ahead of server time;
- expected resolution must be after assignment and no more than one year ahead of server time;
- optional assignment notes are limited to 1,000 characters.

These checks are not authorization. Before assigning, the API must independently verify that the fault belongs to the route station and that the selected technician is active and authorized for that station/category. Use the authorization matrix in `docs/security/SUPPORT-MAINTENANCE-AUTHORIZATION-MATRIX.md`. Assignment and audit persistence remain unimplemented pending schema approval.


## Support incident validation (domain groundwork)

The support-incident policy is a separate domain boundary from equipment-fault reporting. Its current validation rules are:

- Station and reporter IDs are required; reporter identity must ultimately be derived from the validated server-side identity, not request input.
- Category is limited to 2–80 characters, title to 5–160, description to 10–5,000, and the optional affected-asset label to 160.
- Occurrence time is required and cannot exceed server time by more than five minutes.
- An incident marked as operationally impacting must use High or Critical severity.
- A null affected-asset label is valid; an absent/default occurrence timestamp and a null report are invalid.
- Lifecycle transitions are constrained: Submitted → UnderReview/Rejected; UnderReview → Assigned/Rejected; Assigned → InProgress/UnderReview; InProgress → WaitingForInformation/Resolved/Assigned; WaitingForInformation → InProgress/Resolved; Resolved → Closed/InProgress. Closed and Rejected are terminal. Unknown lifecycle values and unsupported transitions must be rejected.

These are domain-policy tests, not a deployed support API. The API must still enforce station ownership, role/permission checks, concurrency, audit logging, and server-derived actor identity. Do not infer authorization from a valid transition. Persistence and routes remain gated on the approved schema review.


## Maintenance progress policy (domain groundwork)

A persistence-independent policy now validates workshop progress updates:
- Fault and station IDs are required; update timestamp is required and cannot be more than five minutes ahead of server time.
- Progress percentage must be between 0 and 100; progress notes are optional and limited to 1,000 characters.
- A report marked Resolved must have 100% progress.
- Closed and Rejected reports do not accept progress updates.

These rules do not authorize the actor or establish that the fault belongs to the route station. The eventual API must check station scope, assignee membership, lifecycle transition, and audit the update before persistence. This policy does not create routes or database objects.
