# METRA role-to-permission policy

This document records the initial conservative allow-list in
`public.metra_role_permissions`. The database mapping is an additional
requirement: a user must also have an active account, approved authority
membership, approved station assignment, an approved unrevoked time-valid
individual permission grant, and an approved, active, non-demo station.

## Observation permissions

| Role | Permission codes |
|---|---|
| `observer` | `observation.create`, `observation.edit_own_draft`, `observation.submit` |
| `station_head` | `observation.review`, `observation.return_for_correction`, `registrations.station.approve`, `users.station.view`, `users.station.manage` |
| `station_auditor` | `observation.review`, `observation.return_for_correction` |
| `chief_auditor` | `observation.approve`, `observation.return_for_correction` |
| `network_director` | No observation permission assigned; `stations.catalogue.review` for station catalogue review |
| `statistics_director` | No observation permission assigned |
| `aftn_operator` | No observation permission assigned |
| `system_admin` | No observation permission assigned; `registrations.system.approve` for second-stage registration approval; `users.station.view`, `users.station.manage` for station-scoped staff directory and limited assignments |

This is deliberately not a global administrator bypass. Additional
permissions must be reviewed against the role's approved responsibilities
before being added through a versioned database migration.

## Station audit log

Station catalogue and station-assignment events are exposed through the
station-scoped `GET /api/v1/stations/{stationId}/audit-log` route. The route
requires `users.station.view`, which is explicitly assigned to `station_head`
and `system_admin`; the service-role RPC returns a constrained projection
rather than the raw audit table. Browser roles cannot execute the RPC directly.

## Station catalogue review

The `network_director` allow-list entry for `stations.catalogue.review` is
added by the insert-only migration
`database/migrations/004_station_catalogue_review_permission.sql`.
The API route `POST /api/v1/stations/{stationId}/review` also requires the
station-scoped authorization RPC, an active account, approved membership,
approved assignment to that exact station, and an approved, unrevoked,
time-valid individual grant. The database review function locks the station
row, enforces the expected `pending` state, validates the decision reason,
and writes an append-only before/after entry to `station_audit_log` in the
same transaction. The API derives the actor exclusively from the verified JWT.

## Important implementation boundary

The observation submission and decision workflows are implemented as
station-scoped API routes and database RPC operations. The role allow-list
alone does not authorize a request: every route must validate its payload,
derive identity from the verified access token, obtain station scope from the
route and trusted database records, call the permission RPC for the exact
permission code, and persist through a server-only database operation.

No station is made operational or approved by this policy. Demo records and
unapproved stations remain ineligible for operational authorization.

## Two-stage registration approval

Registration requests remain pending until two distinct reviewers complete the
workflow. A station head can review only requests for a station to which the
reviewer has an approved, current assignment and an approved individual grant
for `registrations.station.approve`. A second-stage system reviewer must have
the `system_admin` role allow-list entry, a station-scoped assignment, and a
separate approved individual grant for `registrations.system.approve`.
The database function rejects self-review and requires the second reviewer to
differ from the station approver.

The API uses
`public.decide_metra_registration_for_station`, which locks the request row
and verifies that its requested station matches the route station before
delegating to the existing transactional decision function. The wrapper is
executable only by `service_role`; `anon` and `authenticated` cannot invoke
it directly. Successful decisions write `registration_audit_events` in the
same database transaction. The station-scoped audit endpoints expose only
decision metadata and are protected by the corresponding stage permission.

The final system approval creates the approved station assignment and changes
the account state to active atomically. It does not create an unrestricted
global administrator grant. Administrative role assignment and permission
grant/revocation remain separate controlled workflows.

## Station user directory

The read-only endpoint
`GET /api/v1/stations/{stationId}/users` is protected by
`users.station.view` and returns only users with station assignments,
their profile name/phone, account state, assignment role/status and validity
period. The read model is a server-only RPC; `anon` and `authenticated`
cannot execute it directly. The permission allow-list is limited to
`station_head` and `system_admin`, and the station authorization RPC still
requires an approved current assignment and a separate approved individual
permission grant. The directory does not expose email addresses, auth-provider
metadata, passwords, tokens or permission-grant management controls.

## Station assignment lifecycle

`users.station.manage` is allow-listed only for `station_head` and
`system_admin`. The API supports request, second-person approval/rejection,
and audited revocation of station assignments. This station-manager workflow
is deliberately restricted to `observer` and `station_auditor`; it cannot
assign `station_head`, `chief_auditor`, `network_director`,
`statistics_director`, `aftn_operator`, or `system_admin`.

The target must have an active account and an approved, current membership in
the station's authority. The requester cannot assign themselves, the requester
cannot approve their own request, and the target cannot approve or revoke
their own assignment. The database locks pending assignment rows, rejects
overlapping validity periods, and writes request/decision/revocation events to
the append-only `station_audit_log`. Each RPC is executable only by
`service_role`; the API checks the actor's station-scoped permission and
derives the actor from the verified JWT.

Authority membership administration and individual permission-grant/revoke
administration are not exposed through this station workflow. Permission
grants remain separate, explicitly approved records; no assignment endpoint
creates or broadens a permission grant.

## Electronic Auditor permissions (proposed — not wired)

| Code | Intent |
|---|---|
| `electronic_auditor.case.read` | View audit cases for authorized stations |
| `electronic_auditor.case.create` | Open new chart audit case |
| `electronic_auditor.image.upload` | Upload original chart image |
| `electronic_auditor.extract.run` | Calibration and curve extraction |
| `electronic_auditor.compare.run` | Compare to electronic observations + engines |
| `electronic_auditor.decide` | Record audit decision (does not mutate observations) |
| `electronic_auditor.report.read` | Read audit report |

These codes are **documentation only** until owner approval and server enforcement tests exist.
Observer / forecasting read rights do **not** imply `electronic_auditor.decide`.
