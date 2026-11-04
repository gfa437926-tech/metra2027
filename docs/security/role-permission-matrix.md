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
| `station_head` | `observation.review`, `observation.return_for_correction` |
| `station_auditor` | `observation.review`, `observation.return_for_correction` |
| `chief_auditor` | `observation.approve`, `observation.return_for_correction` |
| `network_director` | No observation permission assigned; `stations.catalogue.review` for station catalogue review |
| `statistics_director` | No observation permission assigned |
| `aftn_operator` | No observation permission assigned |
| `system_admin` | No observation permission assigned |

This is deliberately not a global administrator bypass. Additional
permissions must be reviewed against the role's approved responsibilities
before being added through a versioned database migration.

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
