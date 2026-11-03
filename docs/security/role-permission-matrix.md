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
| `network_director` | No observation permission assigned |
| `statistics_director` | No observation permission assigned |
| `aftn_operator` | No observation permission assigned |
| `system_admin` | No observation permission assigned |

This is deliberately not a global administrator bypass. Additional
permissions must be reviewed against the role's approved responsibilities
before being added through a versioned database migration.

## Important implementation boundary

The permission RPC enforces the role allow-list, but the observation write
workflow is not yet implemented. Do not treat this matrix as proof that
observation create/review/approval endpoints are available. A future API
endpoint must independently validate the request, derive user identity from
the verified access token, obtain station scope from trusted data, call the
permission RPC for the exact permission code, and persist through a
server-only database operation.

No station is made operational or approved by this policy. Demo records and
unapproved stations remain ineligible for operational authorization.
