# Equipment Faults — API Contract (Draft)

**Status:** contract proposal; not yet exposed by the API.  
**Scope:** meteorological equipment faults reported by a station. This contract is intentionally independent of any database schema.

## Security invariants

- Require a valid Supabase access token on every endpoint.
- Derive the reporter identity from the validated JWT `sub` claim. Never accept a reporter/user ID supplied by the client as authority.
- Require station-scoped permissions: `equipment_fault.create` for submission; `equipment_fault.read` for reading; `equipment_fault.review`, `equipment_fault.assign`, and `equipment_fault.resolve` for their respective transitions.
- Enforce station scope on the server for every read and mutation. A station manager must not access another station by changing a route ID.
- Record actor, timestamp, previous state, next state, and reason for every decision/transition in an append-only audit trail.
- Keep service-role credentials server-side. Do not return storage keys, signed secrets, or internal exception details.
- Apply bounded request sizes, strict text limits, rate limits, and attachment content/type/size checks before accepting uploads.

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

The station ID comes from the route; the reporter ID comes from the authenticated token. Neither is accepted from the request body.

## Lifecycle

```text
Submitted -> UnderReview -> Assigned -> InProgress -> Resolved -> Closed
      |             |           ^           |
      +-> Rejected  +-> Rejected +-----------+
```

Allowed rework paths: Assigned -> UnderReview and Resolved -> InProgress. Closed and Rejected are terminal. Any other transition returns `409 Conflict`.

## Validation and response rules

- Station and authenticated reporter identities must be valid.
- Category: 2–80 characters; equipment name: 2–120; description: 10–4000.
- Occurrence time is required and cannot be more than five minutes in the future.
- A report marked as operationally blocking must have High or Critical severity.
- Return `201 Created` with a server-generated fault ID on success.
- Return `400` for invalid fields, `401` for missing/invalid authentication, `403` for permission or station-scope failure, `404` for an unknown/inaccessible report, `409` for an invalid lifecycle transition, and `503` when a required dependency is unavailable.
- List endpoints must use bounded pagination and stable ordering. Do not expose unrestricted cross-station queries.

## Not implemented yet

This document and the domain policy do not create tables, RPCs, storage buckets, API routes, or client screens. Before persistence is implemented, the proposed contract and storage design must be reviewed against the approved station catalogue and explicitly approved database schema. No Supabase schema has been changed.
