# IT and Telecommunications Incidents — API Contract (Draft)

**Status:** proposed contract; no HTTP endpoints or persistence adapter are registered yet.  
**Scope:** station-originated information-technology and telecommunications incidents.

## Security and station isolation

- All endpoints require a valid Supabase access token.
- The server derives reporter and actor IDs from the validated JWT; client-supplied identities are never authoritative.
- Every request is authorized against the station in the route. A user cannot broaden access by changing a station or incident ID.
- Proposed permissions: `support_incident.create`, `support_incident.read`, `support_incident.review`, `support_incident.assign`, `support_incident.update`, and `support_incident.resolve`.
- Every assignment, status transition, and resolution note is written to an append-only audit history with actor and timestamp.
- Internal service credentials remain server-side. Attachments require size limits, content inspection, safe generated object names, and station-scoped download authorization.

## Proposed routes

| Method | Route | Purpose |
|---|---|---|
| POST | `/api/v1/stations/{stationId}/support-incidents` | Create an IT or telecom incident |
| GET | `/api/v1/stations/{stationId}/support-incidents` | Bounded, filtered station queue |
| GET | `/api/v1/stations/{stationId}/support-incidents/{incidentId}` | Read incident and authorized history |
| POST | `/api/v1/stations/{stationId}/support-incidents/{incidentId}/assignments` | Assign to an authorized support user |
| POST | `/api/v1/stations/{stationId}/support-incidents/{incidentId}/transitions` | Review, start, request information, resolve, close, or reject |

## Incident types

- `InformationTechnology`: workstation, application, operating system, account/access, local network, printer, and other IT service issues.
- `Telecommunications`: radio, telephone, transmission link, modem/router, antenna, and communication equipment issues.

Category values should be maintained by a controlled server-side catalogue; arbitrary category text must not be used to grant privileges or route work.

## Validation rules

- Station and reporter identities must be valid.
- Category: 2–80 characters; title: 5–160; description: 10–5000.
- Optional affected asset/service name is limited to 160 characters.
- Occurrence time is required and cannot be more than five minutes in the future.
- If operations are impacted, severity must be High or Critical.
- Use bounded pagination and stable ordering; cap free-text search length and apply rate limits.

## Lifecycle

```text
Submitted -> UnderReview -> Assigned -> InProgress -> Resolved -> Closed
      |             |            |          |
      +-> Rejected  +-> Rejected  +-> WaitingForInformation
                                      |
                                      +-> InProgress
```

A resolved incident may return to InProgress for verified rework. Closed and Rejected are terminal. Invalid transitions return `409 Conflict`.

## Response semantics

- `201`: created with server-generated incident ID.
- `400`: field validation failure.
- `401`: missing or invalid token.
- `403`: missing permission or station scope.
- `404`: unknown or inaccessible incident.
- `409`: invalid state transition or concurrency conflict.
- `503`: required dependency unavailable.

## Explicitly out of scope until approved

This draft and the domain policy do not create database tables, RPCs, storage buckets, endpoints, or UI. Before persistence work, the contract, category catalogue, assignment model, and audit design must be reviewed and the Supabase schema explicitly approved. No database has been modified.
